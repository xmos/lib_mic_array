#!/usr/bin/python
import math
import sys

lut_table_size_bits     = ''
lut_unsigned_input_bits = ''
lut_signed_output_bits  = ''
if len(sys.argv) != 4:
    sys.exit("Must provide: lut_table_size_bits lut_unsigned_input_bits lut_signed_output_bits")

lut_table_size_bits = int(sys.argv[1])
lut_unsigned_input_bits = int(sys.argv[2])
lut_signed_output_bits = int(sys.argv[3])

max_output_magnitude = ((1<<(lut_signed_output_bits-1))-1)

print "Writing sin LUT"
print "Total LUT size " + str(2*1<<lut_table_size_bits) + " bytes"
print "Output resolution: " + str(lut_signed_output_bits) + " (Signed)"
print "Input resolution: " + str(lut_unsigned_input_bits) + " (Unsigned)" 

fod = open("sine_lut_data.xc", "wb")
foc = open("sine_lut_const.h", "wb")
foh = open("sine_lut.h", "wb")

foh.write("#ifndef SIN_LUT_H_\n")
foh.write("#define SIN_LUT_H_\n")
foh.write("#include \"sine_lut_const.h\"\n")


foh.write("\n/*\n")
foh.write(" * define theta of 0 to SINE_LUT_INPUT_MASK as 0 to 2*pi\n")
foh.write(" * return sin(theta)\n")
foh.write(" */\n")
foh.write("int sine_lut_sin(unsigned theta);\n")
foh.write("\n/*\n")
foh.write(" * define theta of 0 to SINE_LUT_INPUT_MASK as 0 to 2*pi\n")
foh.write(" * return cos(theta)\n")
foh.write(" */\n")
foh.write("int sine_lut_cos(unsigned theta);\n")
foh.write("\n/*\n")
foh.write(" * define theta of 0 to SINE_LUT_INPUT_MASK as 0 to 2*pi\n")
foh.write(" * return sin(theta) and cos(theta)\n")
foh.write(" */\n")
foh.write("{int, int} sine_lut_sin_cos(unsigned theta);\n")

foh.write("#endif /* SIN_LUT_H_ */\n")

foh.close()

fod.write( "#include \"sine_lut_const.h\"\n")
fod.write( "//Auto-generated - do not edit\n")
fod.write( "const unsigned short sin_lut[SINE_LUT_SIZE] = {\n")
for i in range(0, 1<<lut_table_size_bits):
   var = max_output_magnitude * math.sin((2*math.pi*i)/(1<<(lut_table_size_bits+2)))
   fod.write(str(int(var)))
   fod.write(",\t")
   if (i%8 == 7): 
      fod.write("\n")
fod.write( "};\n")

foc.write( "//Auto-generated - do not edit\n")
foc.write( "#ifndef SIN_LUT_CONST_H_\n");
foc.write( "#define SIN_LUT_CONST_H_\n");
foc.write("\n//This is the period of the input theta(after which it wraps around)\n")
foc.write( "#define SINE_LUT_INPUT_PERIOD ");
foc.write(str(1<<lut_unsigned_input_bits));
foc.write("\n")
foc.write( "#define SINE_LUT_INPUT_MASK ");
foc.write(str((1<<lut_unsigned_input_bits)-1));
foc.write("\n")
foc.write( "#define SINE_LUT_INPUT_BITS ");
foc.write(str(lut_unsigned_input_bits));
foc.write("\n")
foc.write( "#define SINE_LUT_OUTPUT_MAX_MAGNITUDE ");
foc.write(str(max_output_magnitude));
foc.write("\n\n")
foc.write( "#define SINE_LUT_OUTPUT_BITS ");
foc.write(str(lut_signed_output_bits));
foc.write("\n")
foc.write( "#define SINE_LUT_SIZE ");
foc.write(str(1<<lut_table_size_bits));
foc.write( "\n");
foc.write( "#define SINE_LUT_MASK ");
foc.write(str((1<<lut_table_size_bits)-1));
foc.write( "\n");
foc.write( "#define SINE_LUT_BITS ");
foc.write(str(lut_table_size_bits));
foc.write( "\n");
foc.write( "#endif /* SINE_LUT_CONST_H_ */\n");
