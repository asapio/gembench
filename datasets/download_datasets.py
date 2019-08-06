################################################################################
# @ddblock_begin copyright
############################################################################
# Copyright (c) 1997-2019
# Maryland DSPCAD Research Group, The University of Maryland at College Park 
#
# Permission is hereby granted, without written agreement and without license
# or royalty fees, to use, copy, modify, and distribute this software and its
# documentation for any purpose other than its incorporation into a commercial
# product, provided that the above copyright notice and the following two
# paragraphs appear in all copies of this software.
# 
# IN NO EVENT SHALL THE UNIVERSITY OF MARYLAND BE LIABLE TO ANY PARTY
# FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES
# ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF
# THE UNIVERSITY OF MARYLAND HAS BEEN ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
# 
# THE UNIVERSITY OF MARYLAND SPECIFICALLY DISCLAIMS ANY WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE SOFTWARE
# PROVIDED HEREUNDER IS ON AN "AS IS" BASIS, AND THE UNIVERSITY OF
# MARYLAND HAS NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT, UPDATES,
# ENHANCEMENTS, OR MODIFICATIONS.
############################################################################

# @ddblock_end copyright
################################################################################

# This script downloads MDP datasets from various web locations. The MDP files were
# not included in the software release to keep its size small. Please report
# any broken web links to asapio@umd.edu.

import os
import gzip
import tarfile
import sys

if sys.version_info[0] == 2:
    from urllib import urlretrieve
if sys.version_info[0] >= 3:
    from urllib.request import urlretrieve


def download_dataset_cassandra():

    dataset_name = 'cassandra'
    base_url = 'http://www.pomdp.org/examples/'
    mdp_file_list = ['1d.noisy.POMDP',
                     '1d.POMDP',
                     '4x3.95.POMDP',
                     '4x4.95.POMDP',
                     '4x5x2.95.POMDP.gz',
                     'aloha.10.POMDP.gz',
                     'aloha.30.POMDP.gz',
                     'baseball.POMDP.gz',
                     'bridge-repair.POMDP.gz',
                     'bulkhead.A.POMDP.gz',
                     'cheese.95.POMDP',
                     'cheng-examples.tar.gz',
                     'cit.POMDP.gz',
                     'concert.POMDP',
                     'ejs.tar.gz',
                     'fourth.POMDP.gz',
                     'hallway.POMDP.gz',
                     'hallway2.POMDP.gz',
                     'iff.POMDP.gz',
                     'learning.c2.POMDP.gz',
                     'learning.c3.POMDP.gz',
                     'learning.c4.POMDP.gz',
                     'line4-2goals.POMDP',
                     'machine.POMDP.gz',
                     'marking.POMDP',
                     'marking2.POMDP',
                     'mcc-example1.POMDP',
                     'mcc-example2.POMDP',
                     'milos-aaai97.POMDP.gz',
                     'mini-hall2.POMDP',
                     'mit.POMDP.gz',
                     'network.POMDP',
                     'paint.95.POMDP',
                     'parr95.95.POMDP',
                     'pentagon.POMDP.gz',
                     'query.s2.POMDP.gz',
                     'query.s3.POMDP.gz',
                     'query.s4.POMDP.gz',
                     'saci-s100-a10-z31.POMDP.gz',
                     'saci-s12-a6-z5.95.POMDP.gz',
                     'shuttle.95.POMDP',
                     'stand-tiger.95.POMDP',
                     'sunysb.POMDP.gz',
                     'tiger-grid.POMDP.gz',
                     'tiger.95.POMDP',
                     'tiger.aaai.POMDP',
                     'toy-pomdp-probs.tar.gz',
                     'web-ad.POMDP',
                     'web-mall.POMDP']

    # Setup download directory and make sure it exists
    # The download directory will be datasets/cassandra
    this_dir = os.path.dirname(os.path.realpath(__file__))
    download_dir = os.path.join(this_dir, dataset_name)

    if not os.path.exists(download_dir):
        os.mkdir(download_dir)

    # Download each mdp file
    for fname in mdp_file_list:
        full_fname = os.path.join(download_dir, fname)

        # Check if file already exists
        if os.path.isfile(full_fname):
            print("{} already exists, skipping download")
            continue

        # File doesnt exist, we need to download it
        download_url = base_url+fname
        print("Downloading {} to {}".format(download_url, full_fname))
        urlretrieve(download_url, full_fname)

    # Unzip files as needed
    for fname_gz in os.listdir(download_dir):
        full_fname_gz = os.path.join(download_dir, fname_gz)
        if not os.path.isfile(full_fname_gz):
            continue
        if not fname_gz[-3:].upper() == '.GZ':
            continue
        print("\tUnzipping {} => {}".format(fname_gz, fname_gz[0:-3]))

        # Open and unzip the .gz file, extract contents
        with gzip.open(full_fname_gz, 'rb') as f_gz:
            file_contents = f_gz.read()
        # Write unzipped contents to new file
        with open(full_fname_gz[0:-3], 'w') as f:
            f.write(file_contents)
        # Remove .gz version
        os.remove(full_fname_gz)

    for fname_tar in os.listdir(download_dir):
        full_fname_tar = os.path.join(download_dir, fname_tar)
        if not os.path.isfile(full_fname_tar):
            continue
        if not full_fname_tar[-4:].upper() == '.TAR':
            continue
        print("\t\tUntarring {}".format(fname_tar))

        # Open and unzip the .tar file, extract contents
        with tarfile.open(full_fname_tar) as tar:
            # file_contents = f_tar.read()
            tar.extractall(path=download_dir)
            tar.close()

        # Remove .tar version
        os.remove(full_fname_tar)


if __name__ == '__main__':
    download_dataset_cassandra()
