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

def collect_files_from_dir(dir, pattern, env_var):
    files=list()
    env_file_list = None
    if env_var:
        env_file_list = os.getenv(env_var)

    if env_file_list:
        file_names = env_file_list.split('\n')
    else:
        file_names = os.popen('ls -tr {0}'.format(dir)).readlines()
    
    for f in file_names:
        f = f.strip()
        if os.path.isfile('{0}/{1}'.format(dir, f)) and pattern in f and 'summary' not in f:
            files.append(f)
    
    return files


def read_cols(file_path, use_cols=None, delim=',', skip_row=1):
    cols = None
    try:
        cols = np.loadtxt(file_path, skiprows = 0, delimiter = delim, dtype=str, usecols = use_cols, unpack=True)
    except Exception as e:
        print(e.args)

    if cols.ndim == 1:
        return [cols[0]], [map(float, cols[skip_row:])]
    else:
        return cols[:,0], np.array([map(float, col) for col in cols[:,skip_row:]])

def csv_to_line_chart(csv_dir, out_file, left_ax_cols, right_ax_cols, super_title):
    line_weight = 1
    left_colors = ['red', 'darkorange']
    right_colors = ['blue', 'green']
    file_list = collect_files_from_dir(csv_dir, '.csv', 'CSV_FILE_LIST')
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
        barefilename = filename.split('.')[0]       
        axis1 = fig.add_subplot(row_count, col_count, 1 + chartidx)
        chartidx += 1
        axis2 = axis1.twinx()

        # left axis
        sb_headers, sb_cols = read_cols('{0}/{1}.csv'.format(csv_dir, barefilename), left_ax_cols)
        colidx = 0
        for col in sb_cols:
            axis1.plot(col, '-', label=sb_headers[colidx], 
                lw = line_weight, c = left_colors[colidx % len(left_colors)])
            colidx += 1
        
        axis1.margins(0.02)
        axis1.set_ylim(0)
        axis1.set_ylabel(','.join(sb_headers), size=10)
        axis1.set_title(barefilename.split('.')[0], fontsize=14)
        axis1.legend(sb_headers, loc=3, prop={'size': 11})

        # right axis
        io_headers, io_cols = read_cols('{0}/{1}.io'.format(csv_dir, barefilename), right_ax_cols)
        colidx = 0
        for col in io_cols:
            axis2.plot(col, '-', label=io_headers[colidx], 
                lw = line_weight, c = right_colors[colidx % len(right_colors)])
            colidx += 1

        axis2.margins(0.02)
        axis2.set_ylim(0, 100)
        axis2.set_ylabel(','.join(io_headers), size=10)
        axis2.legend(io_headers, loc=4, prop={'size': 11})

    plt.savefig(out_file, bbox_inches = 'tight')


def d2c_to_scatter(d2c_dir, out_file, super_title):
    line_weight = 1
    scatter_color = ['blue']
    file_list = collect_files_from_dir(d2c_dir, 'd2c.dat', None)
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
 
    for filename in file_list:
        axis = fig.add_subplot(row_count, col_count, 1 + chartidx)
        chartidx += 1
        barefilename = filename.split('.')[0]
        d2c_headers, d2c_cols = read_cols('{0}/{1}'.format(d2c_dir, filename), delim=' ', skip_row=0)

        # axis.scatter(d2c_cols[0], ['%.3f'%(lat * 1000) for lat in d2c_cols[1]], 
        axis.scatter(d2c_cols[0], d2c_cols[1], 
                marker = "x", lw = line_weight, c = scatter_color)
        
        axis.margins(0.02)
        axis.set_ylim(0)
        axis.set_ylabel('lat (sec)', size=10)
        axis.set_xlabel('time (sec)', size=10)
        axis.set_title(barefilename, fontsize=14)

    plt.savefig(out_file, bbox_inches = 'tight')

def pxx_from_histo(percentile_number, lat_ary):
    if not len(lat_ary) > 0 or percentile_number >= 100 or percentile_number <= 0:
        print('invalid input parameter! total_cnt > 0; 0 < percentile_number < 100, lat_ary=[[lat,cnt]]')
        return None

    total_cnt = 0
    for item in lat_ary:
        total_cnt += item[1]
    
    target_cnt = total_cnt * (100.0 - percentile_number) / 100

    target_lat = None
    current_cnt = 0
    for i in range(len(lat_ary) - 1, 0, -1):
        current_cnt += lat_ary[i][1]
        if current_cnt > target_cnt:
            target_lat = lat_ary[i][0]
            break
    return target_lat

def retrieve_cols(file_path, exclude_header_list):
    colindexes = list()
    selheaders = list()
    cols = list()
    headers = open(file_path).readline().split(',')
    i = 0
    for i in range(len(headers)):
        h = headers[i].strip()
        if len(h) > 0 and h.strip(':') not in exclude_header_list:
            colindexes.append(i)
            selheaders.append(h)
    try:
        cols = np.loadtxt(file_path, skiprows = 1, delimiter = ',', usecols = colindexes, unpack = True)
    except Exception as e:
        print(i)
        print(e.args)
    return selheaders, cols

def compute_summary(csv_dir, out_file, pxx_list):
    file_list = collect_files_from_dir(csv_dir, '.csv', 'CSV_FILE_LIST')
    skipheaders = ['thrds', '99% latency', 'Device', 'svctm', 'avg-cpu', '%idle', 'ts']
    header_printed = False
    outdata = list()
    caseid = os.getenv('case_id')
    if not caseid:
        caseid = ''

    for filename in file_list:
        selheaders = ['thrd cnt', 'workload']
        barefilename = filename.split('.')[0]
        sb_headers, sb_cols = retrieve_cols('{0}/{1}.csv'.format(csv_dir, barefilename), skipheaders)
        io_headers, io_cols = retrieve_cols('{0}/{1}.io'.format(csv_dir, barefilename), skipheaders)
        
        pxx_headers = list()
        pxx_vals = list()
        if len(pxx_list) > 0:
            histo_f = csv_dir + '/' + barefilename + '.histo'
            histo_ary=np.loadtxt(histo_f, delimiter=',')
            for pxx in pxx_list:
                pxx_headers.append('{0}% latency'.format(pxx))
                pxx_vals.append(pxx_from_histo(pxx, histo_ary))

        # selheaders = ['thrd cnt', 'workload', sb_headers, pxx headers, io_headers]
        selheaders.extend(sb_headers)
        selheaders.extend(pxx_headers)
        selheaders.extend(io_headers)

        if not header_printed:
            outdata.append(','.join(selheaders) + '\n')
            header_printed = True

        fn_list = barefilename.split('_')
        row = list([fn_list[-1], ' '.join(fn_list[0:-1])])
        for col in sb_cols:
            row.append(col.mean())

        for val in pxx_vals:
            row.append(val)

        for col in io_cols:
            row.append(col.mean())
        
        outdata.append(','.join(row[0:2]) + ',' + ','.join('{0:.2f}'.format(i) for i in row[2:]) + '\n')
    
    open(out_file, 'w+').writelines(outdata)

#
# -l data columns are from sysbench result files, like oltp_read_only_1.csv
# -r data columns are from iostat result files, like oltp_read_only_1.io
# -p sysbench TPS percentile numbers are calculated from histogram files, 
#    like oltp_read_only_1.histo
def process_args(argv):
    help_str = '{0} -d path_to_csv_dir -o png_file -l column_id1[,column_id2] -r column_id1[,column_id2] [-s path_to_summary_csv] [-t chart_super_title]'.format(sys.argv[0])

    try:
        opts, args = getopt.getopt(argv[1:], 'hd:s:o:l:r:t:p:b')
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
    pxx_list = list()
    blktrace = False

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
        elif opt == '-p':
            pxx_list=[float(idx) for idx in arg.split(',')]

    if len(csv_dir) == 0 or len(out_file) == 0:
        print(help_str)
        sys.exit(2)
    
    if len(left_ax_cols) == 0 or len(right_ax_cols) == 0:
        print(help_str)
        sys.exit(2)

    return csv_dir, out_file, left_ax_cols, right_ax_cols, summary_file, super_title, pxx_list

if __name__ == '__main__':
    csv_dir, out_file, left_ax_cols, right_ax_cols, summary_file, super_title, pxx_list = process_args(argv)
    csv_to_line_chart(csv_dir, out_file, left_ax_cols, right_ax_cols, super_title)
    if len(summary_file) > 0:
        compute_summary(csv_dir, summary_file, pxx_list)
    env_blktrace = os.getenv('collect_blktrace')
    if env_blktrace and env_blktrace != "0":
        d2c_dir = '/'.join(csv_dir.split('/')[:-1]) + '/d2c'
        d2c_outfile = '/'.join(out_file.split('/')[:-1]) + '/result_d2c.png'
        d2c_to_scatter(d2c_dir, d2c_outfile, super_title)

