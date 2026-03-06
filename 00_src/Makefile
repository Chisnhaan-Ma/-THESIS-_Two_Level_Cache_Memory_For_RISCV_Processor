# Compiler
IVERILOG = iverilog
VVP      = vvp
GTKWAVE  = gtkwave

# File
TOP      = Pipeline_Tb.sv
OUT      = tb.vvp
LOG      = store.log
VCD      = wave.vcd

# Compile
$(OUT): $(TOP)
	$(IVERILOG) -g2012 -o $(OUT) $(TOP)

# Run simulation
sim: $(OUT)
	$(VVP) $(OUT) > $(LOG)

# Run + open waveform
wave: $(OUT)
	$(VVP) $(OUT) > $(LOG)
	$(GTKWAVE) $(VCD)

# Clean
clean:
	rm -f $(OUT) $(LOG) $(VCD)