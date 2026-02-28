# SimVision Command Script (Fri Dec 05 10:30:48 PM +07 2025)
#
# Version 24.09.s005
#
# You can restore this configuration with:
#
#     simvision -input crashrecovery.tcl
#  or simvision -input crashrecovery.tcl database1 database2 ...
#


#
# Preferences
#
preferences set plugin-enable-svdatabrowser-new 1
preferences set plugin-enable-groupscope 0
preferences set plugin-enable-interleaveandcompare 0
preferences set plugin-enable-waveformfrequencyplot 0

#
# Databases
#
array set dbNames ""
set dbNames(realName1) simulator

#
# Mnemonic Maps
#
mmap new  -reuse -name {Boolean as Logic} -radix %b -contents {{%c=FALSE -edgepriority 1 -shape low}
{%c=TRUE -edgepriority 1 -shape high}}
mmap new  -reuse -name {Example Map} -radix %x -contents {{%b=11???? -bgcolor orange -label REG:%x -linecolor yellow -shape bus}
{%x=1F -bgcolor red -label ERROR -linecolor white -shape EVENT}
{%x=2C -bgcolor red -label ERROR -linecolor white -shape EVENT}
{%x=* -label %x -linecolor gray -shape bus}}

#
# Waveform windows
#
if {[catch {window new WaveWindow -name "Waveform 1" -geometry 1920x1025+0+31}] != ""} {
    window geometry "Waveform 1" 1920x1025+0+31
}
window target "Waveform 1" on
waveform using {Waveform 1}
waveform sidebar select designbrowser
waveform set \
    -primarycursor TimeA \
    -signalnames name \
    -signalwidth 175 \
    -units ns \
    -valuewidth 75
waveform baseline set -time 0

set id [waveform add -signals [subst  {
	{$dbNames(realName1)::[format {tbench.dut.memory_top.i_mem_inst[31:0]}]}
	} ]]
set id [waveform add -signals [subst  {
	{$dbNames(realName1)::[format {tbench.dut.memory_top.i_mem_pc[31:0]}]}
	} ]]
set id [waveform add -signals [subst  {
	{$dbNames(realName1)::[format {tbench.dut.memory_top.i_mem_alu_data[31:0]}]}
	} ]]
set id [waveform add -signals [subst  {
	{$dbNames(realName1)::[format {tbench.dut.memory_top.ld_data[31:0]}]}
	} ]]
set id [waveform add -signals [subst  {
	{$dbNames(realName1)::[format {tbench.dut.memory_top.lsu_memory.o_ld_data[31:0]}]}
	} ]]
set id [waveform add -signals [subst  {
	{$dbNames(realName1)::[format {tbench.dut.memory_top.lsu_memory.en_datamem}]}
	} ]]
set id [waveform add -signals [subst  {
	{$dbNames(realName1)::[format {tbench.dut.memory_top.lsu_memory.i_lsu_addr[31:0]}]}
	} ]]
set id [waveform add -signals [subst  {
	{$dbNames(realName1)::[format {tbench.dut.memory_top.lsu_memory.mem.o_data[31:0]}]}
	} ]]
waveform hierarchy collapse $id
set id [waveform add -signals [subst  {
	{$dbNames(realName1)::[format {tbench.dut.memory_top.lsu_memory.i_lsu_wren}]}
	} ]]

waveform xview limits 994.2ns 1057ns

#
# Waveform Window Links
#

#
# Layout selection
#

