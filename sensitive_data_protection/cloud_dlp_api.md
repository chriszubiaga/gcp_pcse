# Cloud Data Loss Prevention API

## Overview

This lab introduces the Cloud Data Loss Prevention (DLP) API, now part of Google Cloud's Sensitive Data Protection suite. The DLP API provides programmatic access to a powerful engine for detecting and managing personally identifiable information (PII) and other sensitive data within unstructured data streams. It supports various data types, including text and images, and can process data sent directly to the API or stored in Cloud Storage, BigQuery, and Cloud Datastore.

In this lab, you will use the DLP API to inspect a string of text for sensitive information (like phone numbers) and then use it to redact sensitive information (like email addresses) from another string.

## What You'll Learn

* How to use the DLP API to inspect a string for sensitive information.
* How to use the DLP API to redact sensitive data from text content.
* Basic structure of DLP API requests (JSON) and how to make calls using `curl`.
* Understanding `infoTypes`, `inspectConfig`, and `deidentifyConfig`.

## Setup and Requirements

* Standard Google Cloud lab environment.
* Access to Cloud Shell for running `gcloud` and `curl` commands.

**1. Activate Cloud Shell**
   * Click the "Activate Cloud Shell" button at the top of the Google Cloud Console.

**2. Set Environment Variable for Project ID**
   * In Cloud Shell, run the following to make it easier to reference your Project ID:
    ```bash
    export PROJECT_ID=$(gcloud config get-value project)
    # You can also use the pre-set DEVSHELL_PROJECT_ID if available:
    # export PROJECT_ID=$DEVSHELL_PROJECT_ID
    echo "Project ID set to: $PROJECT_ID"
    ```

## Task 1: Inspect a String for Sensitive Information

This task demonstrates how to use the `projects.content.inspect` REST method of the DLP API to scan a sample text string for specified types of sensitive data.

**1. Create the JSON Request File (`inspect-request.json`)**

* Using a text editor in Cloud Shell (like `nano` or `vim`), create a file named `inspect-request.json` with the following content:
    ```json
    {
      "item":{
        "value":"My phone number is (206) 555-0123."
      },
      "inspectConfig":{
        "infoTypes":[
          {
            "name":"PHONE_NUMBER"
          },
          {
            "name":"US_TOLLFREE_PHONE_NUMBER"
          }
        ],
        "minLikelihood":"POSSIBLE",
        "limits":{
          "maxFindingsPerItem":0
        },
        "includeQuote":true
      }
    }
    ```
    * **`item.value`**: The string of text to inspect.
    * **`inspectConfig.infoTypes`**: An array specifying the types of sensitive information to look for (e.g., `PHONE_NUMBER`).
    * **`inspectConfig.minLikelihood`**: The minimum likelihood level for a finding to be reported (e.g., `POSSIBLE`, `LIKELY`, `VERY_LIKELY`).
    * **`inspectConfig.limits.maxFindingsPerItem`**: `0` means no limit on the number of findings per item.
    * **`inspectConfig.includeQuote`**: If `true`, the actual sensitive data string found (the "quote") is included in the response.

**2. Obtain an Authorization Token**

* API requests to Google Cloud services require an OAuth 2.0 access token for authentication.
    ```bash
    gcloud auth print-access-token
    ```
* This command will output a long string. Copy this token. You'll use it as `ACCESS_TOKEN` in the next step.
    * *Note: If you get an error, wait a few moments and try again. Tokens are short-lived.*

**3. Make the `content:inspect` API Request using `curl`**

* Replace `ACCESS_TOKEN` in the command below with the token you just copied.
    ```bash
    curl -s \
      -H "Authorization: Bearer ACCESS_TOKEN" \
      -H "Content-Type: application/json" \
      https://dlp.googleapis.com/v2/projects/$PROJECT_ID/content:inspect \
      -d @inspect-request.json -o inspect-output.txt
    ```
    * **`-H "Authorization: Bearer ACCESS_TOKEN"`**: Passes the access token for authentication.
    * **`-H "Content-Type: application/json"`**: Indicates the request body is JSON.
    * **`https://dlp.googleapis.com/v2/projects/$PROJECT_ID/content:inspect`**: The DLP API endpoint for inspecting content.
    * **`-d @inspect-request.json`**: Sends the content of `inspect-request.json` as the request body.
    * **`-o inspect-output.txt`**: Saves the API response to a file named `inspect-output.txt`.
    * **`-s`**: Silent mode for curl.

**4. Review the Output**

* Display the contents of the output file:
    ```bash
    cat inspect-output.txt
    ```
* **Expected Output (similar to):**
    ```json
    {
      "result": {
        "findings": [
          {
            "quote": "(206) 555-0123",
            "infoType": {
              "name": "PHONE_NUMBER"
            },
            "likelihood": "LIKELY",
            "location": {
              "byteRange": {
                "start": "19",
                "end": "33"
              },
              "codepointRange": {
                "start": "19",
                "end": "33"
              }
            },
            "createTime": "2018-07-03T02:20:26.043Z" 
            // Note: createTime will vary
          }
        ]
      }
    }
    ```
    This shows that the API found a `PHONE_NUMBER` with a `LIKELY` likelihood.

**5. Upload Output to Cloud Storage (Lab Specific)**
    * The lab requires uploading the output for validation. Replace `bucket_name_filled_after_lab_start` with the actual bucket name provided in your lab environment.
    ```bash
    gsutil cp inspect-output.txt gs://bucket_name_filled_after_lab_start/
    ```

## Task 2: Redacting Sensitive Data from Text Content

This task demonstrates how the DLP API can automatically de-identify (redact) sensitive information found in text using the `projects.content.deidentify` method.

**1. Create the JSON Request File (`new-inspect-file.json`)**

* Create a file named `new-inspect-file.json` with the following content:
    ```json
    {
      "item": {
         "value":"My email is test@gmail.com"
       },
       "deidentifyConfig": {
         "infoTypeTransformations":{
              "transformations": [
                {
                  "primitiveTransformation": {
                    "replaceWithInfoTypeConfig": {}
                  }
                }
              ]
            }
        },
        "inspectConfig": {
          "infoTypes": [ # Note: The lab example shows "infoTypes": {"name": "EMAIL_ADDRESS"} which might be a typo. It should usually be an array.
            { # Corrected to be an array of infoType objects
              "name": "EMAIL_ADDRESS"
            }
          ]
        }
    }
    ```
    * **`item.value`**: The string containing the email address.
    * **`deidentifyConfig.infoTypeTransformations.transformations`**: Defines how to transform detected infoTypes.
        * **`primitiveTransformation.replaceWithInfoTypeConfig`**: A simple transformation that replaces the detected sensitive data with the name of the infoType (e.g., `[EMAIL_ADDRESS]`).
    * **`inspectConfig.infoTypes`**: Specifies to look for `EMAIL_ADDRESS`.

**2. Make the `content:deidentify` API Request using `curl`**

* This command directly embeds the command to get an access token.
    ```bash
    curl -s \
      -H "Authorization: Bearer $(gcloud auth print-access-token)" \
      -H "Content-Type: application/json" \
      https://dlp.googleapis.com/v2/projects/$PROJECT_ID/content:deidentify \
      -d @new-inspect-file.json -o redact-output.txt
    ```
    * **`https://dlp.googleapis.com/v2/projects/$PROJECT_ID/content:deidentify`**: The DLP API endpoint for de-identifying content.
    * The rest of the `curl` options are similar to the previous request.

**3. Review the Output**

* Display the contents of the output file:
    ```bash
    cat redact-output.txt
    ```
* **Expected Output (similar to):**
    ```json
    {
      "item": {
        "value": "My email is [EMAIL_ADDRESS]"
      },
      "overview": {
        "transformedBytes": "14", // This value may vary
        "transformationSummaries": [
          {
            "infoType": {
              "name": "EMAIL_ADDRESS"
            },
            "transformation": {
              "replaceWithInfoTypeConfig": {}
            },
            "results": [
              {
                "count": "1",
                "code": "SUCCESS"
              }
            ],
            "transformedBytes": "14" // This value may vary
          }
        ]
      }
    }
    ```
    The output shows the `item.value` with the email address replaced by `[EMAIL_ADDRESS]`.

**4. Upload Output to Cloud Storage (Lab Specific)**
    * Replace `bucket_name_filled_after_lab_start` with the actual bucket name.
    ```bash
    gsutil cp redact-output.txt gs://bucket_name_filled_after_lab_start/
    ```

## Key Concepts and Important Points

* **Cloud Data Loss Prevention (DLP) API (Sensitive Data Protection):**
    * A service to discover, classify, and protect sensitive data.
    * Can scan data in various Google Cloud storage services (Cloud Storage, BigQuery, Datastore) as well as data streams sent directly to the API.

* **Programmatic Access:**
    * The DLP API is accessed via REST (or gRPC) endpoints.
    * Requests and responses are typically in JSON format.
    * Requires authentication using OAuth 2.0 access tokens (often obtained via `gcloud auth print-access-token` for testing/scripting).

* **Core DLP API Methods Used:**
    * **`projects.content.inspect`**: Used for detecting and classifying sensitive data within provided content. It returns "findings" detailing what was found, where, and with what likelihood.
    * **`projects.content.deidentify`**: Used for transforming (e.g., redacting, masking, encrypting) sensitive data within provided content based on inspection results.

* **Key Request Components:**
    * **`item`**: Contains the data to be processed (e.g., `item.value` for a direct string).
    * **`inspectConfig`**: Defines how the inspection should be performed.
        * **`infoTypes`**: Specifies the types of sensitive data to search for (e.g., `PHONE_NUMBER`, `EMAIL_ADDRESS`, `CREDIT_CARD_NUMBER`, `US_SOCIAL_SECURITY_NUMBER`). Google provides many predefined infoTypes.
        * **`minLikelihood`**: Filters findings based on the likelihood score (e.g., `POSSIBLE`, `LIKELY`, `VERY_LIKELY`) that a piece of data matches an infoType.
        * **`includeQuote`**: Determines if the actual found data (the quote) should be returned in the inspection results.
    * **`deidentifyConfig`**: Defines how detected sensitive data should be transformed.
        * **`infoTypeTransformations`**: Specifies transformations to apply to specific infoTypes.
        * **`primitiveTransformation`**: Defines the actual transformation method.
            * `replaceWithInfoTypeConfig`: Replaces the sensitive data with its infoType name (e.g., "john.doe@example.com" becomes "[EMAIL_ADDRESS]"). Other transformations include masking, bucketing, date shifting, cryptographic replacement, etc.

* **API Response:**
    * For inspection, the response includes a list of `findings`. Each finding details the `quote` (if requested), `infoType`, `likelihood`, and `location`.
    * For de-identification, the response includes the transformed `item` and an `overview` of the transformations performed.

* **Use Cases:**
    * Discovering where sensitive data resides.
    * Redacting PII from text or images before display or further processing.
    * Tokenizing data for analytics while preserving privacy.
    * Helping to comply with data privacy regulations.