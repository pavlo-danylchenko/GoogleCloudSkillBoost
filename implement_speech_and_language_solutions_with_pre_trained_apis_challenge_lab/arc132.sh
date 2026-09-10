#!/bin/bash
set -euo pipefail


echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"

export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

echo $ZONE
echo $REGION

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION


echo "======================================================================"
echo "                        Task 1. Create an API key"
echo "======================================================================"
gcloud services api-keys create \
    --display-name="API key 1" \
    --api-target=service=language.googleapis.com \
    --api-target=service=speech.googleapis.com \
    --api-target=service=texttospeech.googleapis.com \
    --api-target=service=translate.googleapis.com

sleep 5

KEY_NAME=$(gcloud services api-keys list --filter="display_name='API key 1'" --format="value(name)")
API_KEY=$(gcloud services api-keys get-key-string $KEY_NAME --format="value(keyString)")


gcloud compute instances add-metadata lab-vm \
    --zone=$ZONE \
    --project=$DEVSHELL_PROJECT_ID \
    --metadata=API_KEY=$API_KEY


cat > start.sh << 'EOF'
source venv/bin/activate

export API_KEY=$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/attributes/API_KEY)
echo "API Key retrieved from metadata: $API_KEY"

cat > synthesize-text.json << EOF_1
{
    'input':{
        'text':'Cloud Text-to-Speech API allows developers to include
           natural-sounding, synthetic human speech as playable audio in
           their applications. The Text-to-Speech API converts text or
           Speech Synthesis Markup Language (SSML) input into audio data
           like MP3 or LINEAR16 (the encoding used in WAV files).'
    },
    'voice':{
        'languageCode':'en-gb',
        'name':'en-GB-Standard-A',
        'ssmlGender':'FEMALE'
    },
    'audioConfig':{
        'audioEncoding':'MP3'
    }
}
EOF_1

curl -X POST \
    -H "Content-Type: application/json" \
    -d @synthesize-text.json "https://texttospeech.googleapis.com/v1/text:synthesize?key=${API_KEY}" \
    > synthesize-text.txt

cat > tts_decode.py << EOF_2
import argparse
from base64 import decodebytes
import json

"""
Usage:
        python tts_decode.py --input "Filled in at lab start" \
        --output "synthesize-text-audio.mp3"

"""

def decode_tts_output(input_file, output_file):
    """ Decode output from Cloud Text-to-Speech.

    input_file: the response from Cloud Text-to-Speech
    output_file: the name of the audio file to create

    """

    with open(input_file) as input:
        response = json.load(input)
        audio_data = response['audioContent']

        with open(output_file, "wb") as new_file:
            new_file.write(decodebytes(audio_data.encode('utf-8')))

if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description="Decode output from Cloud Text-to-Speech",
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--input',
                       help='The response from the Text-to-Speech API.',
                       required=True)
    parser.add_argument('--output',
                       help='The name of the audio file to create',
                       required=True)

    args = parser.parse_args()
    decode_tts_output(args.input, args.output)
EOF_2

python tts_decode.py --input "synthesize-text.txt" --output "synthesize-text-audio.mp3"


echo "======================================================================"
echo "Task 3. Perform speech to text transcription with the Cloud Speech API"
echo "======================================================================"
cat > speech_request.json << EOF_3
{
  "config": {
      "encoding":"FLAC",
      "languageCode": "fr-FR"
  },
  "audio": {
      "uri":"gs://cloud-samples-data/speech/corbeau_renard.flac"
  }
}
EOF_3

curl -s -X POST \
    -H "Content-Type: application/json" \
    -d @speech_request.json "https://speech.googleapis.com/v1/speech:recognize?key=${API_KEY}" \
    > speech_response_fr.json


echo "======================================================================"
echo "       Task 4. Translate text with the Cloud Translation API"
echo "======================================================================"
cat > tr.json << EOF_4
{
  "q": "これは日本語です。",
  "target": "en",
  "format": "text"
}
EOF_4

curl -X POST \
    -H "Content-Type: application/json" \
    -d @tr.json "https://translation.googleapis.com/language/translate/v2?key=${API_KEY}" \
    > translation_response.txt


echo "======================================================================"
echo "       Task 5. Detect a language with the Cloud Translation API"
echo "======================================================================"
cat > detect.json << EOF_5
{
  "q": "Este%é%japonês.",
  "format": "text"
}
EOF_5

curl -X POST \
    -H "Content-Type: application/json" \
    -d @detect.json "https://translation.googleapis.com/language/translate/v2/detect?key=${API_KEY}" \
    > detection_response.txt

curl "https://translation.googleapis.com/language/translate/v2/detect?key=${API_KEY}&q=${TEXT}" \
    > detection_response.txt

EOF

# To execute once:
gcloud compute ssh lab-vm \
    --zone=$ZONE \
    --quiet \
    --project=$DEVSHELL_PROJECT_ID \
    --command="bash -s" < ./start.sh

echo "======================================================================"
echo "                         JOB is DONE !!!"
echo "======================================================================"