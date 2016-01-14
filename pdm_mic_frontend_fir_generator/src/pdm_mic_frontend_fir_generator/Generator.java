package pdm_mic_frontend_fir_generator;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Calendar;

public class Generator {	
	
	final int maxCoefsPerThirdPhase = 32;
	final double PDMClockRate = 3072000; //MHz
	
	private double [] read_array(String filename){
		
		ArrayList<String> records = new ArrayList<String>();
		try
		  {
		    BufferedReader reader = new BufferedReader(new FileReader(filename));
		    String line;
		    while ((line = reader.readLine()) != null)
		    {
		      records.add(line);
		    }
		    reader.close();
		  }
		  catch (Exception e)
		  {
		    System.err.format("Exception occurred trying to read '%s'.", filename);
		    e.printStackTrace();
		  }
		
		double coefs[] = new double[records.size()];
		
		int i=0;
		
		for(String s : records){
			coefs[i] = Double.parseDouble(s);
			i++;
		}
		
		return coefs;
		
	}

	String first_define;
	String second_define;
	
	private void output_first_fir(String filename, String name, BufferedWriter header, BufferedWriter impl) throws IOException{

		double coefs[] = read_array(filename);
		
		double abs_sum = 0;
		double sum = 0;
		
		for(int i=0;i<coefs.length;i++)
			sum += coefs[i];
		
		for(int i=0;i<coefs.length;i++)
			coefs[i]/=sum;
		
		for(int i=0;i<coefs.length;i++)
			abs_sum += Math.abs(coefs[i]);
		
		first_define = name.toUpperCase()+ "_STAGE_SCALE_FACTOR";
		header.write("#define " +first_define + " (" + abs_sum + ")\n");
		System.out.println("//" +name+ " stage FIR length: " + coefs.length +" at PDM clock rate = " + 0.5*1000*(coefs.length / PDMClockRate) +"ms");
		
		long t_sum_abs = 0;
		for(int t=0;t<coefs.length/8/2;t++){

			int v = 0;
			
			impl.write("int g_" +name+ "_fir_"+t+" [256] = {\n");
			impl.write("\t");
			for(int x=0;x<256;x++){
				double d = 0.0;
				for(int b=0;b<8;b++){
					if(((x>>(7-b))&1) == 1) 
						d += coefs[t*8 + b];
					else 
						d -= coefs[t*8 + b];
				}
				int d_int = (int)(d*Integer.MAX_VALUE/abs_sum);

				v = Math.max(v, Math.abs(d_int));
				impl.write(String.format("0x%08x, ", d_int));
				if((x&7)==7)
					impl.write("\n\t");
			}
			impl.write("};\n");
			
			t_sum_abs += v*2;
			
		}

		System.out.println("//Max " +name + " FIR output value: " + 
				t_sum_abs +"("+(Integer.MAX_VALUE - t_sum_abs) +") " + " -> " + 
				100.0*t_sum_abs / Integer.MAX_VALUE +"% of full scale\n\n");
		
		impl.write("int fir1_debug[" + coefs.length + "] = {\n");
		header.write("extern int fir1_debug[" + coefs.length + "];\n\n");
		for(int i=0;i<coefs.length;i++){
			impl.write(String.format("%9d, ", (int)(coefs[i]*Integer.MAX_VALUE/abs_sum)));
			if((i&7)==7)
				impl.write("\n");
		}
		impl.write("};\n\n");
	}
	
	private void output_second_fir(String filename, String name, BufferedWriter header, BufferedWriter impl) throws Exception{

		double coefs[] = read_array(filename);
		double abs_sum = 0;
		double sum = 0;
		
		for(int i=0;i<coefs.length;i++)
			sum += coefs[i];
		
		for(int i=0;i<coefs.length;i++)
			coefs[i]/=sum;

		for(int i=0;i<coefs.length;i++)
			abs_sum += Math.abs(coefs[i]);
		
		second_define = name.toUpperCase()+ "_STAGE_SCALE_FACTOR";
		header.write("#define " +second_define+ " (" + abs_sum + ")\n");
		System.out.println("//" +name+ " stage FIR length: " + coefs.length+" at (PDM clock rate)/8 = " + 0.5*1000*(coefs.length / (PDMClockRate/8)) +"ms");

		long t_sum_pos = 0;
		long t_sum_neg = 0;

		double max = 0.0;
		
		impl.write("int g_" +name+ "_fir["+coefs.length/2 + "] = {\n");
		for(int i=0;i<coefs.length/2;i++){
			double d=coefs[i]/abs_sum;
			max = Math.max(max, d);
			int d_int = (int)(d*(double)Integer.MAX_VALUE);
			impl.write(String.format("\t0x%08x,\n", d_int));
			if(d_int>0){
				t_sum_pos += ((long)d_int * (long) Integer.MAX_VALUE);
				t_sum_pos += ((long)d_int * (long) Integer.MAX_VALUE);
				t_sum_neg += ((long)d_int * (long) Integer.MIN_VALUE);
				t_sum_neg += ((long)d_int * (long) Integer.MIN_VALUE);
			} else {
				t_sum_pos += ((long)d_int * (long) Integer.MIN_VALUE);
				t_sum_pos += ((long)d_int * (long) Integer.MIN_VALUE);
				t_sum_neg += ((long)d_int * (long) Integer.MAX_VALUE);
				t_sum_neg += ((long)d_int * (long) Integer.MAX_VALUE);
			}
		}
		impl.write("};\n");

		if(max > 0.5)
			throw new Exception("Single coefficient too big"); 
		
		int max_output = (int) ((t_sum_pos*2)>>32);
		int min_output = (int) ((t_sum_neg*2)>>32);
		System.out.println("//Max " +name + " FIR output value: " + 
				max_output +"("+(Integer.MAX_VALUE - max_output) +") " + " -> " + 
				100.0*max_output / Integer.MAX_VALUE +"% of full scale");
		
		System.out.println("//Min " +name + " FIR output value: " + 
				min_output +"("+(Integer.MAX_VALUE - min_output) +") " + " -> " + 
				100.0*min_output / Integer.MAX_VALUE +"% of full scale\n\n");
		
		impl.write("int fir2_debug[" + coefs.length + "] = {\n");
		header.write("extern int fir2_debug[" + coefs.length + "];\n\n");
		for(int i=0;i<coefs.length;i++){
			impl.write(String.format("%9d, ", (int)(coefs[i]*Integer.MAX_VALUE/abs_sum)));
			if((i&7)==7)
				impl.write("\n");
		}
		impl.write("};\n\n");
	}	

	private void output_third_fir_doubled(String filename, String name, BufferedWriter header, BufferedWriter impl) throws Exception{

		double coefs[] = read_array(filename);
		final int phases = coefs.length/maxCoefsPerThirdPhase;
		
		double abs_sum = 0;
		double sum = 0;
		
		for(int i=0;i<coefs.length;i++)
			sum += coefs[i];
		
		for(int i=0;i<coefs.length;i++)
			coefs[i]/=sum;

		for(int i=0;i<coefs.length;i++)
			abs_sum += Math.abs(coefs[i]);

		String third_define = "THIRD_STAGE_" +name.toUpperCase()+ "_SCALE_FACTOR";
		header.write("#define " +third_define + "  (" + abs_sum + ")\n");
		
		
		header.write("#define DECIMATION_FACTOR_"+name.toUpperCase() +" (" + phases + ")\n");
		header.write("#define FIR_COMPENSATOR_"+name.toUpperCase()+" ((int)((double)INT_MAX/4.0 * " +
		first_define +" * "+ second_define +" * "+ third_define + "))\n");
		
		System.out.println("//" +name+ " stage FIR length: " + coefs.length + " at (PDM clock rate)/32 = "
		+ 0.5*1000*(coefs.length / (PDMClockRate/(32))) +"ms");

		long t_sum_pos = 0;
		long t_sum_neg = 0;

		impl.write("int g_third_" +name+ "_fir["+(2*coefs.length-phases)+ "] = {\n");
		header.write("extern int g_third_" +name+ "_fir["+(2*coefs.length-phases)+ "];\n");
		
		double max = 0.0;
		for(int phase = 0 ;phase < phases; phase++){
			impl.write("//Phase " + phase + "\n");
			for(int i=0;i<coefs.length/phases;i++){
				
				int index = coefs.length - phases - (i*phases - phase);
				double d=coefs[index]/abs_sum*2.0;
				max = Math.max(max, d);
				int d_int = (int)(d*(double)Integer.MAX_VALUE);
				impl.write(String.format("0x%08x, ", d_int));
				if(((i)%8)==7) impl.write("\n");
				if(d_int>0){
					t_sum_pos += ((long)d_int * (long) Integer.MAX_VALUE);
					t_sum_neg += ((long)d_int * (long) Integer.MIN_VALUE);
				} else {
					t_sum_pos += ((long)d_int * (long) Integer.MIN_VALUE);
					t_sum_neg += ((long)d_int * (long) Integer.MAX_VALUE);
				}
			}
			for(int i=0;i<coefs.length/phases-1;i++){
				int index = coefs.length - phases - (i*phases - phase);
				double d=coefs[index]/abs_sum*2.0;
				max = Math.max(max, d);
				int d_int = (int)(d*(double)Integer.MAX_VALUE);
				impl.write(String.format("0x%08x, ", d_int));
				if(((i)%8)==7) impl.write("\n");
			}
			impl.write("\n");
		}
		impl.write("};\n");

		if(max > 0.5)
			throw new Exception("Single coefficient too big"); 
		
		int max_output = (int) (t_sum_pos>>32);
		int min_output = (int) (t_sum_neg>>32);
		System.out.println("//Max " +name + " FIR output value: " + 
				max_output +"("+(Integer.MAX_VALUE - max_output) +") " + " -> " + 
				100.0*max_output / Integer.MAX_VALUE +"% of full scale");
		
		
		System.out.println("//Min " +name + " FIR output value: " + 
				min_output +"("+(Integer.MAX_VALUE - min_output) +") " + " -> " + 
				100.0*min_output / Integer.MAX_VALUE +"% of full scale");
		System.out.println("\n");
		
		impl.write("int fir3_"+ name+"_debug[" + coefs.length+ "] = {\n");
		header.write("extern int fir3_"+ name+"_debug[" + coefs.length + "];\n\n");
		for(int i=0;i<coefs.length;i++){
			impl.write(String.format("%9d, ", (int)(coefs[i]*Integer.MAX_VALUE/abs_sum)));
			if((i&7)==7)impl.write("\n");
		}
		impl.write("};\n");
	}
	
	public void go(){

		BufferedWriter header = null;
		BufferedWriter impl = null;
		try {
			header = new BufferedWriter( new FileWriter( "fir_decimator.h"));
			impl = new BufferedWriter( new FileWriter( "fir_coefs.xc"));
			
			int year = Calendar.getInstance().get(Calendar.YEAR);
			header.write("// Copyright (c) " +year +", XMOS Ltd, All rights reserved\n");
			impl.write("// Copyright (c) " +year +", XMOS Ltd, All rights reserved\n");
			header.write("#ifndef FIR_DECIMATOR_H_\n");
			header.write("#include <limits.h>\n");
			header.write("#define FIR_DECIMATOR_H_\n");

			output_first_fir("first_h.txt", "first", header, impl);
			
			output_second_fir("second_h.txt", "second", header, impl);
			output_third_fir_doubled("third_stage_div_2_h.txt", "div_2", header, impl);
			output_third_fir_doubled("third_stage_div_4_h.txt", "div_4", header, impl);
			output_third_fir_doubled("third_stage_div_6_h.txt", "div_6", header, impl);
			output_third_fir_doubled("third_stage_div_8_h.txt", "div_8", header, impl);
			output_third_fir_doubled("third_stage_div_12_h.txt",  "div_12", header, impl);
			
			header.write("#define THIRD_STAGE_COEFS_PER_STAGE (" + (maxCoefsPerThirdPhase) +")\n");
			header.write("#define THIRD_STAGE_COEFS_PER_ROW   (" + (2*maxCoefsPerThirdPhase-1) +")\n");
			header.write("#endif /* FIR_DECIMATOR_H_ */\n");

		} catch (Exception e) {
			e.printStackTrace();
		}
		finally
		{
		    try
		    {
		        if ( header != null)
		        	header.close( );
		        if ( impl != null)
		        	impl.close( );
		    }
		    catch ( IOException e)
		    {
				e.printStackTrace();
		    }
		}
	}
	public static void main(String[] args) {
		Generator m = new Generator();
		m.go();
	}

}
