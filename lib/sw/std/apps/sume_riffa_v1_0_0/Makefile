#
# Copyright (c) 2015 University of Cambridge
# Copyright (c) 2015 Bjoern A. Zeeb
# All rights reserved.
#
#  File:
#        Makefile
#
# This software was developed by the University of Cambridge Computer Laboratory 
# under EPSRC INTERNET Project EP/H040536/1, National Science Foundation under Grant No. CNS-0855268,
# and Defense Advanced Research Projects Agency (DARPA) and Air Force Research Laboratory (AFRL), 
# under contract FA8750-11-C-0249.
#
# @NETFPGA_LICENSE_HEADER_START@
#
# Licensed to NetFPGA Open Systems C.I.C. (NetFPGA) under one or more contributor
# license agreements.  See the NOTICE file distributed with this work for
# additional information regarding copyright ownership.  NetFPGA licenses this
# file to you under the NetFPGA Hardware-Software License, Version 1.0 (the
# "License"); you may not use this file except in compliance with the
# License.  You may obtain a copy of the License at:
#
#   http://www.netfpga-cic.org
#
# Unless required by applicable law or agreed to in writing, Work distributed
# under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
# CONDITIONS OF ANY KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations under the License.
#
# @NETFPGA_LICENSE_HEADER_END@
#

all:	rwaxi register_read.sh register_write.sh

rwaxi:	rwaxi.c ${DRIVER_FOLDER}/nf_sume.h
	cc -Wall -Werror -o rwaxi rwaxi.c \
		-I${DRIVER_FOLDER}

register_read.sh:	generate_register_read.sh ${NF_DESIGN_DIR}/sw/embedded/src/sume_register_defines.h
	sh generate_register_read.sh

register_write.sh:	generate_register_read.sh ${NF_DESIGN_DIR}/sw/embedded/src/sume_register_defines.h
	sh generate_register_write.sh

clean:
	rm -f rwaxi register_read.sh register_write.sh

# end
