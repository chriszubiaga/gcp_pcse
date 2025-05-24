# Google Cloud Sensitive Data Protection (DLP) - Challenge Lab

Based on the lab: [Get Started with Sensitive Data Protection: Challenge Lab](https://www.cloudskillsboost.google.com/course_templates/750/labs/510997)

## Overview

This challenge lab tests skills in using the Sensitive Data Protection API for redacting, de-identifying, and creating inspection templates.

## Challenge Scenario

As a junior cloud engineer, you need to use the Sensitive Data Protection service to:

*   Redact sensitive information from text.
*   De-identify sensitive data.
*   Create DLP templates for inspecting structured and unstructured data.

## Tasks and Steps

### Task 1: Redact sensitive data from text content

```bash
    export PROJECT_ID=$(gcloud config get-value project)
    export INPUT_FILE=redact-request.json
    export OUTPUT_FILE=redact-response.txt
    export BUCKET=qwiklabs-gcp-02-eaf844e2c00b-redact  # Replace with your lab-provided bucket name

    echo '{
        "item": {
                "value": "Please update my records with the following information:\n Email address: foo@example.com,\nNational Provider Identifier: 1245319599"
        },
        "deidentifyConfig": {
                "infoTypeTransformations": {
                        "transformations": [{
                                "primitiveTransformation": {
                                        "replaceWithInfoTypeConfig": {}
                                }
                        }]
                }
        },
        "inspectConfig": {
                "infoTypes": [{
                                "name": "EMAIL_ADDRESS"
                        },
                        {
                                "name": "US_HEALTHCARE_NPI"
                        }
                ]
        }
    }' | jq > $INPUT_FILE



    curl -s \
      -H "Authorization: Bearer $(gcloud auth print-access-token)" \
      -H "Content-Type: application/json" \
      https://dlp.googleapis.com/v2/projects/$PROJECT_ID/content:deidentify \
      -d @$INPUT_FILE -o $OUTPUT_FILE

    gsutil cp $OUTPUT_FILE gs://$BUCKET
```

### Task 2: Create DLP inspection templates (gcloud CLI)

First, create a file named `structured_template_config.yaml` with the following content:

```yaml
deidentifyTemplate:
  deidentifyConfig:
    recordTransformations:
      fieldTransformations:
      - fields:
        - name: bank name
        - name: zip code
        primitiveTransformation:
          maskingConfig:
            maskingCharacter: '#'
            fullyMaskConfig: {}
      - fields:
        - name: message
        primitiveTransformation:
          replaceWithInfoTypeConfig: {}
```

Then, create the structured data de-identify template using the `gcloud` CLI (replace `<YOUR_PROJECT_ID>`):

```bash
gcloud dlp deidentify-templates create structured_data_template \
  --location=us \
  --config-file=structured_template_config.yaml \
  --project=<YOUR_PROJECT_ID>
```

Next, create a file named `unstructured_template_config.yaml` with the following content:

```yaml
deidentifyTemplate:
  deidentifyConfig:
    infoTypeTransformations:
      transformations:
      - primitiveTransformation:
          replaceConfig:
            newValue:
              stringValue: "[redacted]"
```

Then, create the unstructured data de-identify template using the `gcloud` CLI (replace `<YOUR_PROJECT_ID>`):

```bash
gcloud dlp deidentify-templates create unstructured_data_template \
  --location=us \
  --config-file=unstructured_template_config.yaml \
  --project=<YOUR_PROJECT_ID>
```

### Task 3: Configure a job trigger to run DLP inspection (gcloud CLI)

First, create a file named `job_trigger_config.yaml` with the following content. Replace `<YOUR_PROJECT_ID>`, `<YOUR_INPUT_BUCKET_URL>`, and `<YOUR_OUTPUT_BUCKET_URL>` with your actual lab-provided values.

```yaml
inspectJob:
  storageConfig:
    cloudStorageOptions:
      fileSet:
        url: <YOUR_INPUT_BUCKET_URL>
      bytesLimitPerFilePercent: 100
      sampleMethod: NO_SAMPLING
  actions:
  - deidentify:
      cloudStorageOutput: <YOUR_OUTPUT_BUCKET_URL>
      templatedDeidentifyTemplate: projects/<YOUR_PROJECT_ID>/locations/us/deidentifyTemplates/structured_data_template # Use your structured template resource name
      templated:
        inspectTemplate: {} # You might need to specify an inspect template if not using default
        deidentifyTemplate: projects/<YOUR_PROJECT_ID>/locations/us/deidentifyTemplates/unstructured_data_template # Use your unstructured template resource name
schedule:
  weeklySchedule:
    dayOfWeek: SUNDAY # Or any other day for weekly
```

Then, create the job trigger using the `gcloud` CLI (replace `<YOUR_PROJECT_ID>`):

```bash
gcloud dlp job-triggers create \
  --location=us \
  --inspect-template-ids="" \
  --trigger-id=dlp_job \
  --config-file=job_trigger_config.yaml \
  --project=<YOUR_PROJECT_ID>
```

After creating the job trigger, you can manually run it using the `gcloud` CLI (replace `<YOUR_PROJECT_ID>`):

```bash
gcloud dlp job-triggers activate dlp_job \
  --location=us \
  --project=<YOUR_PROJECT_ID>
```

Remember to monitor the job execution in the Google Cloud console or using `gcloud dlp jobs list` and verify the output in the specified Cloud Storage bucket.