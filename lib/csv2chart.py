#!/usr/bin/env python
#!encoding=utf-8

import sys
from sys import argv
import os
import getopt
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np


def is_below_2_7():
    if sys.version_info[0] <= 2 and sys.version_info[1] < 7:
        return True
    return False

def collect_csv_files(csv_dir):
    env_csv_file_list = os.getenv('CSV_FILE_LIST')
    if env_csv_file_list:
        files = env_csv_file_list.split('\n')
    else:
        files = os.popen('ls -tr {0}'.format(csv_dir)).readlines()
    csv_files = list()
    for f in files:
        f = f.strip()
        if os.path.isfile(csv_dir + '/' + f) and ".csv" in f and 'summary' not in f:
            csv_files.append(f)
    return csv_files

def convert_csv_to_png(csv_dir, out_file, left_ax_cols, right_ax_cols, super_title):
    line_weight = 1
    left_colors = ['red', 'darkorange']
    right_colors = ['blue', 'green']
    file_list = collect_csv_files(csv_dir)
    chartidx = 0

    caseid = os.getenv('case_id')
    if not caseid:
        caseid = ''

    col_count = 2
    if len(file_list) <= 1:
        col_count = 1
    row_count = len(file_list) / 2 + len(file_list) % 2
    fig = plt.figure(figsize=(14 * col_count, 5 * row_count))
    fig.suptitle(super_title, fontsize=16)
 
    exp_print = False

    for filename in file_list:
        file_path = csv_dir + '/' + filename

        headers = open(file_path).readline().split(',')
       
        axis1 = fig.add_subplot(row_count, col_count, 1 + chartidx)
        chartidx += 1
        axis2 = axis1.twinx()

        try:
            cols = np.loadtxt(file_path, skiprows = 1, delimiter = ',', usecols = left_ax_cols, unpack=True)
        except Exception as e:
            print(e.args)
            continue

        colidx = 0
        if len(left_ax_cols) == 1:
            axis1.plot(cols, '-', label=headers[left_ax_cols[colidx]], lw = line_weight, c = left_colors[0])
        else:
            for col in cols:
                axis1.plot(col, '-', label=headers[left_ax_cols[colidx]], 
                    lw = line_weight, c = left_colors[colidx % len(left_colors)])
                colidx += 1
        
        try:
            cols = np.loadtxt(file_path, skiprows = 1, delimiter = ',', usecols = right_ax_cols, unpack=True)
        except Exception as e:
            print(e.args)
            continue

        colidx = 0
        if len(right_ax_cols) == 1:
            axis2.plot(cols, '-', label=headers[right_ax_cols[colidx]], 
                lw = line_weight, c = right_colors[0])
        else:
            for col in cols:
                axis2.plot(col, '-', label=headers[right_ax_cols[colidx]], 
                    lw = line_weight, c = right_colors[colidx % len(right_colors)])
                colidx += 1

        axis1.set_ylim(0)
        axis1.set_ylabel(','.join(headers[i] for i in left_ax_cols), size=10)
        axis1.set_title(filename.split('.')[0], fontsize=14)
        
        if not is_below_2_7():
            axis1.get_yaxis().set_major_formatter(
                matplotlib.ticker.FuncFormatter(lambda x, p: '{:,d}'.format(int(x))))

        axis2.set_ylim(0, 100)
        axis2.set_ylabel(','.join(headers[i] for i in right_ax_cols), size=10)

        axis1.legend([headers[i] for i in left_ax_cols], loc=3)
        axis2.legend([headers[i] for i in right_ax_cols], loc=4)

    plt.savefig(out_file, bbox_inches = 'tight')

def compute_summary(csv_dir, out_file):
    file_list = collect_csv_files(csv_dir)
    skipheaders = ['thrds', 'Device', 'rrqm/s', 'svctm', 'avg-cpu', '%idle', 'ts']
    header_printed = False
    outdata = list()
    caseid = os.getenv('case_id')
    if not caseid:
        caseid = ''

    for filename in file_list:
        file_path = csv_dir + '/' + filename
        headers = open(file_path).readline().split(',')
        colindexes = list()
        selheaders = ['thrd cnt', 'workload']
        for i in range(len(headers)):
            if len(headers[i].strip()) > 0 and headers[i].strip().strip(':') not in skipheaders:
                colindexes.append(i)
                selheaders.append(headers[i])
        try:
            cols = np.loadtxt(file_path, skiprows = 1, delimiter = ',', usecols = colindexes, unpack = True)
        except Exception as e:
            print(e.args)
            continue
        
        fn_list = filename.split('.')[0].replace('_', ' ')
        fn_list = [fn_list[-1], fn_list[0:-1]]
        row = list()
        for col in cols:
            row.append(col.mean())
        if not header_printed:
            outdata.append(','.join(selheaders))
            header_printed = True
        outdata.append(','.join(fn_list) + ',' + ','.join('{0:.2f}'.format(i) for i in row) + '\n')
    
    open(out_file, 'w+').writelines(outdata)

def process_args(argv):
    help_str = '{0} -d path_to_csv_dir -o png_file -l column_id1[,column_id2] -r column_id1[,column_id2] [-s path_to_summary_csv] [-t chart_super_title]'.format(sys.argv[0])

    try:
        opts, args = getopt.getopt(argv[1:], 'hd:s:o:l:r:t:')
    except getopt.GetoptError:
        print(help_str)
        sys.exit(1)
    
    csv_dir = ''
    out_file = ''
    # default data columns are TPS/%sys in sysbench result csv
    left_ax_cols = list([1])
    right_ax_cols = list([21])
    summary_file = ''
    super_title = ''

    for opt, arg in opts:
        if opt == '-h':
            print(help_str)
            sys.exit()
        elif opt == '-d':
            csv_dir = arg
        elif opt == '-o':
            out_file = arg
        elif opt == '-l':
            left_ax_cols = [int(idx) for idx in arg.split(',')]
        elif opt == '-r':
            right_ax_cols = [int(idx) for idx in arg.split(',')]
        elif opt == '-s':
            summary_file = arg
        elif opt == '-t':
            super_title = arg

    if len(csv_dir) == 0 or len(out_file) == 0:
        print(help_str)
        sys.exit(2)
    
    if len(left_ax_cols) == 0 or len(right_ax_cols) == 0:
        print(help_str)
        sys.exit(2)

    return csv_dir, out_file, left_ax_cols, right_ax_cols, summary_file, super_title

if __name__ == '__main__':
    csv_dir, out_file, left_ax_cols, right_ax_cols, summary_file, super_title = process_args(argv)
    convert_csv_to_png(csv_dir, out_file, left_ax_cols, right_ax_cols, super_title)
    if len(summary_file) > 0:
        compute_summary(csv_dir, summary_file)

