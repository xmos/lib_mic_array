AUDIO_LENGTH_S=10

#Generate sines
echo "Generating sine waves for test"
sox -n -c 1 -b 32 -r 16000 ch_a_src.wav synth $AUDIO_LENGTH_S sine 1000
sox -n -c 1 -b 32 -r 16000 ch_b_src.wav synth $AUDIO_LENGTH_S sine 300

wait $!

#PCM to PDM
python3 pcm_to_pdm.py --output-rate 3072000 --verbose ch_a_src.wav ch_a.pdm & 
pids=$!
python3 pcm_to_pdm.py --output-rate 3072000 --verbose ch_b_src.wav ch_b.pdm &
pids+=" "$!


wait $pids


#Run simulation
echo "Running firmware"
axe bin/test_mic_dual.xe

#Add wav headers onto output PCM binaries
sox --endian little -c 1 -r 16000 -b 32 -e signed-integer ch_a.raw ch_a.wav
sox --endian little -c 1 -r 16000 -b 32 -e signed-integer ch_b.raw ch_b.wav

#Do the THD calc
python3 thdncalculator.py ch_a.wav & python3 thdncalculator.py ch_b.wav

#Remove tmp files
rm *.wav
rm *.pdm
rm *.raw