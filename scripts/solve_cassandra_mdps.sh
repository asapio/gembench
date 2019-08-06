#!/bin/bash

################################################################################
# @ddblock_begin copyright
#
# Copyright (c) 1997-2019
# Maryland DSPCAD Research Group, The University of Maryland at College Park 
#
# Permission is hereby granted, without written agreement and without license
# or royalty fees, to use, copy, modify, and distribute this software and its
# documentation for any purpose other than its incorporation into a commercial
# product, provided that the above copyright notice and the following two
# paragraphs appear in all copies of this software.

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
#
# @ddblock_end copyright
################################################################################


MAX_RUNTIME_S=180
SOLVER_NAME=spvi

for filename in ../datasets/cassandra/*.POMDP; do 
    ../src/build/gembench -m "$filename" -s "$SOLVER_NAME" -t "$MAX_RUNTIME_S"
done
