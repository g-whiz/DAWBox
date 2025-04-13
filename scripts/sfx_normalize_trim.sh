#/bin/bash 

for F in "$@"
do 	echo "=== Normalizing and Trimming $F ==="
	if [[ $F != *.wav ]]
	then	echo "Skipping $F... Unrecognized format."
		continue
	fi

	if [[ $F == *.normalized.* ]]
	then	echo "Skipping $F... Likely already normalized SFX."
		continue
	fi

	if [[ $F == *.trimmed.normalized.* ]]
	then	echo "Skipping $F... Likely already trimmed an normalized."
		continue
	fi
	
	norm_input_file=$F
	norm_output_file=${F%.*}.normalized.wav
	trimmed_input_file=$norm_output_file
	trimmed_output_file=${F%.*}.trimmed.normalized.wav

	# ffmpeg-normalize true peak (best for SFX)
	ffmpeg-normalize "$norm_input_file" -nt peak -t -4 -f -o "$norm_output_file"

	# ffmpeg -y -i ./dp-ghost-appear001.wav -pass 1 -filter:a loudnorm=I=-16:LRA=11:TP=-1.5:print_format=json,areverse,silenceremove=start_periods=1:start_duration=0.01:start_threshold=-60dB:detection=peak,areverse,silenceremove=start_periods=1:start_duration=0.01:start_threshold=-60dB:detection=peak -c:a pcm_s16le -ac 2 -ar 44800 ./dp-ghost-appear001-normalized.wav
	
	normalization=loudnorm=I=-16:LRA=11:TP=-1.5:print_format=json
	trim_filter=silenceremove=start_periods=1:start_duration=0:start_threshold=-70dB:window=0:detection=peak
	ffmpeg -y -i "$trimmed_input_file" -pass 1 -filter:a areverse,$trim_filter,areverse,$trim_filter -c:a pcm_s16le -ac 2 -ar 44800 "$trimmed_output_file"
	echo "Removing intermediate file: <$norm_output_file> ..."
	rm "$norm_output_file"
	echo "Saved file as: <$trimmed_output_file> ..."
done

