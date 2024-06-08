# Deepfake voices from Youtube

The [domesticatedviking](https://github.com/domesticatedviking) posted his project [TextyMcSpeechy](https://github.com/domesticatedviking/TextyMcSpeechy) to github. A project that provides a step by step guide to creating deep fake voices using [Piper](https://github.com/rhasspy/piper)

I was interested in this from the perspective of "how easy / hard is this actually" and started to follow along

The core of any such deepfake is a supply of samples of the target voice with transcripts. As I had no one in mind to fake I had no such source. Then I remembered that I liked to follow [Patrick Boyle](https://www.youtube.com/@PBoyle), a financial podcaster, on Youtube. His podcast is cleanly recorded featuring only his voice for 20-30 minutes an episode. So I had the source of audio, all I needed was the transcript

Which is a feature of Youtube too. It is not perfect and tends to split the audio up according to how long a segment has been running rather than at the end of a full sentence. But it's better than doing it by had. So we have all the parts, how do we automate?

Here is a little script called `./fetch`

```bash
#!/usr/bin/env bash

FILENAME=$1

if [ ! -e ${FILENAME}.mp4 ]; then
  echo "Getting ${FILENAME}.mp4"
  yt-dlp -q -f "bestaudio[ext=m4a]","bestaudio[ext=webm]" ${FILENAME} -o ${FILENAME}.mp4
else
  echo "Using existing ${FILENAME}.mp4"
fi

if [ ! -e ${FILENAME}.en.json3 ]; then
  echo "Getting the transcription"
  yt-dlp -q --skip-download --write-subs --write-auto-subs --sub-lang en --sub-format json3 --convert-subs srt --output ${FILENAME} ${FILENAME}
else
  echo "Using existing ${FILENAME}.en.json3"
fi

echo "Extracting audio from ${FILENAME}"
ffmpeg -v 0 -y -i ${FILENAME}.mp4 -ac 1 -ar 22050 ${FILENAME}.wav

if [ -e ${FILENAME}.wav ] ; then
  echo "Segmenting"
  ./parse_json3 ${FILENAME}.en.json3
else
  echo "Did not generate ${FILENAME}.wav"
fi

echo

rm ${FILENAME}.mp4
rm ${FILENAME}.wav
rm ${FILENAME}.en.json3
```

Call this with the Youtube id, `./fetch 91UQfdUtTc0`, and the rest is handled for us. First we use [yt-dlp](https://github.com/yt-dlp/yt-dlp) to download the best available audio and follow up by downloading the transcript

Next we use `ffmpeg` to extract the audio to a mono wav file at 22050Hz which is the format that Piper will work with. The next part, `./parse_json3`, will read the transcript file which looks like this

```json
{
  "events": [
  	{
   		"tStartMs": 179,
    	"dDurationMs": 3031,
    	"segs": [
    		{ "utf8": "The US real estate market has frozen up." }
    	]
  	}
	...
  ]
}
```

This is read that the words "The US real estate market has frozen up." starts 179 ms from the start of the data and last for 3031 ms. With this information `./parse_json3` calls `segment` which reads the wav file and chops out a chunk of the data from 179 ms in for 3031 ms and writes it to it's own file, `91UQfdUtTc0_00001.wav`, in the `data` directory and adds a line to `91UQfdUtTc0.txt` that Piper will also need

```
91UQfdUtTc0_00001|0|The US real estate market has frozen up.
```

The `_00001` indicates that this is the first sample, the next one will be called `_00002` and so on. A single episode of Patrick Boyle's podcast will generate around 220-250 samples. Segments less than a second are ignored as the Youtube transcription tends to give the duration as an absurdly small value which Piper will reject so we discard it here and save ourselves the abundant log lines that Piper will give us when it encounters samples that are too short

Here is an example of a very short sample

```json
{
	"tStartMs": 1277631,
	"dDurationMs": 1,
	"segs": [
		{ "utf8": "Bye." }
	]
}
```

I refuse to believe that "Bye" can be uttered in 1 ms

So when we have processed all our episodes we will have a `data` directory with the samples and a file like `91UQfdUtTc0.txt` for each episode that we processed. We will need to combine them with `cat *.txt > data/metadata.csv`

We now have the data we need to follow along with domesticatedviking's tutorial

So we now have samples. But how many will we need?

We start with a base checkpoint which was generated to a given epoch, 9029 in my case, and we will need to train our data against it for around 1,000 epochs. Sounds good so I grabbed 40 episodes and chopped them up and ended up with 18,000 samples. The more the merrier surely. 1 epoch took 22 minutes on my RTX3070, so I was looking at 366 hours to train (15.5 days)

I am not a patient man and my PC is not quiet so I consulted with with domesticatedviking and he told me that he uses around 250-500 samples when he does this. I cut back to 2 podcasts which yielded 502 samples and 1 epoch now took less than a minute. Fired it up and went to bed. In the morning I had processed >1,000 epochs!

Converted the training data to a model by following domesticatedviking's instruction and success. It sounds just like Patrick Boyle. I am a happy bunny

My code is hacked in two languages, Ruby and Python, and is by no means efficient. Sometimes Youtube does not supply a usable transcription or an audio format that `ffmpeg` can work with. When I said I initially grabbed 40 episodes what I really meant was that I grabbed 60 but 20 of them failed for some reason. Rather than fixing what was wrong it was easier just to grab another episode and see if that works. Patrick Boyle has 363 episodes so even with a 33% failure rate I will find more samples than I can realistically process on my little RTX3070

## Examples

In the project are two wav files for the utterance "The US real estate market has frozen up.". The first one, `sample1.wav`, has been generated by Piper and the seconds one, `sample2.wav`, is the phrase from the training data

The quality of the fake is so good that you will just have to take my word that the fake is the first sample and the original is the second. There is no easy way to tell them apart

## Issues

One thing that I have noted, in the admittedly limited examples I have, is that the utterance taken from the transcript and the portion of the wav file that relates to it start to become out of sync as time progresses. After about 100 utterances entire words can be missing from the wav file compared to the transcript

Perhaps cutting off after 100 utterances might improve the quality but somehow it worked regardless. Ah the mysteries of AI :)

