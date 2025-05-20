# Redacting Critical Data with Sensitive Data Protection 

## Overview

This lab introduces the capabilities of the Cloud Data Loss Prevention (DLP) API, which is part of Google Cloud's Sensitive Data Protection service. Sensitive Data Protection is a fully managed service designed to help discover, classify, and protect sensitive information. The DLP API can classify data by type, sensitivity, and category, and offers various protection methods such as redaction, masking, tokenization, and encryption.

In this lab, you will use Node.js client library examples to interact with the DLP API to inspect strings and files for sensitive information, de-identify data using masking, and redact sensitive data from both text and images.

## What You'll Learn

* How to inspect strings and files for various sensitive `infoTypes` using the DLP API.
* Understanding and applying de-identification techniques, specifically character masking.
* How to redact sensitive `infoTypes` from strings and images.
* Basic interaction with the DLP API via Node.js client library samples.

## Setup and Requirements

* Standard Google Cloud lab environment.
* Access to Cloud Shell.

**1. Activate Cloud Shell**
   * Click the "Activate Cloud Shell" button at the top of the Google Cloud Console.

**2. Set Project ID and Region**
   * In Cloud Shell, set your Project ID environment variable:
    ```bash
    export PROJECT_ID=$(gcloud config get-value project)
    # Or: export PROJECT_ID="PROJECT_ID_FROM_LAB_DETAILS"
    gcloud config set project $PROJECT_ID
    ```
   * Set the compute region (as specified in the lab, replace `Region` if a specific one is given):
    ```bash
    gcloud config set compute/region Region
    ```

## Task 1. Clone the Repo and Enable APIs

This task involves setting up the environment by cloning a repository containing Node.js samples for the DLP API and enabling the necessary Google Cloud APIs.

**1. Clone Repository and Install Dependencies**

* Clone the repository (Note: The lab specifies `googleapis/synthtool`, which is a broad repository. The actual samples are likely within a subdirectory focused on DLP):
    ```bash
    git clone [https://github.com/googleapis/synthtool](https://github.com/googleapis/synthtool)
    ```
* Navigate to the specific Node.js DLP samples directory and install packages:
    ```bash
    cd synthtool/tests/fixtures/nodejs-dlp/samples/
    npm install
    ```
    *(Ignore any warning messages during `npm install`)*

**2. Enable Required APIs**

* The lab requires the DLP API and Cloud Key Management Service (KMS) API. While KMS is enabled, this lab primarily demonstrates DLP features not directly dependent on KMS for these specific redaction/masking methods.
* Enable the APIs:
    ```bash
    gcloud services enable dlp.googleapis.com cloudkms.googleapis.com \
        --project $PROJECT_ID
    ```

## Task 2. Inspect Strings and Files

This task demonstrates using the DLP API to inspect text content (both direct strings and content from files) for sensitive information.

**1. Inspect a String**

* The `inspectString.js` script is used. It takes the Project ID and the string to inspect as arguments.
* By default, it inspects for `CREDIT_CARD_NUMBER`, `PHONE_NUMBER`, `PERSON_NAME`, and `EMAIL_ADDRESS`.
* Execute the script:
    ```bash
    node inspectString.js $PROJECT_ID "My email address is jenny@somedomain.com and you can call me at 555-867-5309" > inspected-string.txt
    ```
* View the output:
    ```bash
    cat inspected-string.txt
    ```
* **Expected Output (example):**
    ```
    Findings:
        Info type: PERSON_NAME
        Likelihood: POSSIBLE
        Info type: EMAIL_ADDRESS
        Likelihood: LIKELY
        Info type: PHONE_NUMBER
        Likelihood: VERY_LIKELY
    ```
    The output shows detected `infoTypes` and their `likelihood`.

**2. Inspect a File**

* Review the sample file `resources/accounts.txt`:
    ```bash
    cat resources/accounts.txt
    ```
    *(Content: "My credit card number is 1234 5678 9012 3456, and my CVV is 789.")*
* Use the `inspectFile.js` script to inspect the file:
    ```bash
    node inspectFile.js $PROJECT_ID resources/accounts.txt > inspected-file.txt
    ```
* View the output:
    ```bash
    cat inspected-file.txt
    ```
* **Expected Output (example):**
    ```
    Findings:
        Info type: CREDIT_CARD_NUMBER
        Likelihood: VERY_LIKELY
    ```

**Understanding the `inspectString` API Call (Conceptual based on script description):**
The Node.js script likely constructs a request object for the DLP API's `inspectContent` method:
```javascript
// Conceptual structure based on lab description
const request = {
  parent: `projects/${projectId}/locations/global`, // DLP API calls are often regional or global
  inspectConfig: {
    infoTypes: infoTypes, // e.g., [{name: 'PHONE_NUMBER'}, {name: 'EMAIL_ADDRESS'}]
    minLikelihood: minLikelihood, // e.g., 'POSSIBLE'
    includeQuote: includeQuote, // boolean, true to get the matched text
    limits: {
      maxFindingsPerRequest: maxFindings, // 0 for no limit on findings per item
    },
  },
  item: {value: string}, // The string content to inspect
};
// const [response] = await dlp.inspectContent(request);
```

**3. Upload Output to Cloud Storage (Lab Specific)**

  * Replace `bucket_name_filled_after_lab_start` with the actual bucket name provided in your lab.
    ```bash
    gsutil cp inspected-string.txt gs://bucket_name_filled_after_lab_start/
    gsutil cp inspected-file.txt gs://bucket_name_filled_after_lab_start/
    ```

## Task 3. De-identification

De-identification is the process of removing or obscuring identifying information from data. This task demonstrates de-identification using character masking.

**1. De-identify with Masking**

  * The `deidentifyWithMask.js` script is used.
  * Execute the script with a sample string:
    ```bash
    node deidentifyWithMask.js $PROJECT_ID "My order number is F12312399. Email me at anthony@somedomain.com" > de-identify-output.txt
    ```
  * View the output:
    ```bash
    cat de-identify-output.txt
    ```
  * **Expected Output (example):**
    ```
    My order number is F12312399. Email me at *****************************
    ```
    The email address is masked with `*` characters by default.

**Understanding the `deidentifyWithMask` API Call (Conceptual):**
The script uses the `deidentifyContent` method. The request would include a `deidentifyConfig`:

```javascript
// Conceptual structure
const request = {
  parent: `projects/${projectId}/locations/global`,
  deidentifyConfig: {
    infoTypeTransformations: {
      transformations: [
        {
          primitiveTransformation: { // Apply to all infoTypes if not specified, or specific ones
            characterMaskConfig: {
              maskingCharacter: '*', // Character to use for masking
              // numberToMask: 0, // Number of characters to mask (0 might mean all)
            },
          },
        },
      ],
    },
  },
  item: {value: string}, // The string content
  // inspectConfig might also be needed to tell DLP what to look for before transforming
};
// const [response] = await dlp.deidentifyContent(request);
```

**2. Upload Output to Cloud Storage (Lab Specific)**
` bash gsutil cp de-identify-output.txt gs://bucket_name_filled_after_lab_start/  `

## Task 4. Redact Strings and Images

Redaction is another de-identification method where the sensitive data is replaced, often with the name of the infoType itself (e.g., "[EMAIL\_ADDRESS]"). This task covers text and image redaction.

**1. Redact Text from a String**

  * The `redactText.js` script is used. It takes the Project ID, the string, and the `infoType` to redact as arguments.
  * Execute the script:
    ```bash
    node redactText.js $PROJECT_ID "Please refund the purchase to my credit card 4012888888881881" CREDIT_CARD_NUMBER > redacted-string.txt
    ```
  * View the output:
    ```bash
    cat redacted-string.txt
    ```
  * **Expected Output:**
    ```
    Please refund the purchase on my credit card [CREDIT_CARD_NUMBER]
    ```

**Understanding the `redactText` API Call (Conceptual):**
This also uses the `deidentifyContent` method, but with a specific transformation (`replaceWithInfoTypeConfig`).

```javascript
// Conceptual structure
const request = {
  parent: `projects/${projectId}/locations/global`,
  item: { value: string },
  deidentifyConfig: {
    infoTypeTransformations: {
      transformations: [
        {
          // If specific infoTypes are targeted, 'infoTypes' field would be here
          primitiveTransformation: {
            replaceWithInfoTypeConfig: {}, // Replaces with [INFO_TYPE_NAME]
          },
        },
      ],
    },
  },
  inspectConfig: { // To specify what to look for
    infoTypes: [{ name: 'CREDIT_CARD_NUMBER' }], // As passed to the script
    minLikelihood: minLikelihood, // e.g., 'LIKELY'
  },
};
// const [response] = await dlp.deidentifyContent(request);
```

**2. Redact Information from an Image**

  * The DLP API can also process images to find and redact text containing sensitive information.
  * The `redactImage.js` script takes Project ID, input image filepath, output image filepath, and the `infoType` to redact.
  * Redact phone number from `resources/test.png`:
    ```bash
    node redactImage.js $PROJECT_ID resources/test.png "" PHONE_NUMBER ./redacted-phone.png
    ```
    *(The empty string `""` might be for `minLikelihood` or an unused parameter in this script version).*
  * A new image `redacted-phone.png` is created with the phone number blacked out. You can view it using the Cloud Shell Editor's file browser.
  * Redact email address from the same image:
    ```bash
    node redactImage.js $PROJECT_ID resources/test.png "" EMAIL_ADDRESS ./redacted-email.png
    ```
  * A new image `redacted-email.png` is created.

**Understanding the `redactImage` API Call (Conceptual):**
The script uses the `redactImage` DLP API method.

```javascript
// Conceptual structure
const request = {
  parent: `projects/${projectId}/locations/global`,
  byteItem: { // Image data sent as bytes
    type: fileTypeConstant, // e.g., 'IMAGE_PNG', 'IMAGE_JPEG'
    data: fileBytes, // Base64 encoded image data
  },
  inspectConfig: {
    infoTypes: [{ name: 'PHONE_NUMBER' }], // Or EMAIL_ADDRESS
    minLikelihood: minLikelihood,
  },
  imageRedactionConfigs: [ // Array of redaction configurations
    {
      // Can specify an infoType to redact, or redact all text if infoType not specified
      infoType: { name: 'PHONE_NUMBER' },
      // redactAllText: true, // Alternative to redacting specific infoTypes
      // redactionColor: { red: 0, green: 0, blue: 0 } // Black, default
    }
  ],
};
// const [response] = await dlp.redactImage(request); // response contains redactedImage
```

**3. Upload Output to Cloud Storage (Lab Specific)**
` bash gsutil cp redacted-string.txt gs://bucket_name_filled_after_lab_start/ gsutil cp redacted-phone.png gs://bucket_name_filled_after_lab_start/ gsutil cp redacted-email.png gs://bucket_name_filled_after_lab_start/  `

## Key Concepts and Important Points

  * **Sensitive Data Protection (Cloud DLP API):**

      * A managed Google Cloud service for discovering, classifying, and protecting sensitive data.
      * Supports various data sources, including direct content submission (text, images), Cloud Storage, BigQuery, and Datastore.

  * **Core API Interactions (demonstrated via Node.js client library):**

      * **Inspection (`inspectContent`):** Detects and classifies sensitive data.
          * Identifies `infoTypes` (predefined categories like `EMAIL_ADDRESS`, `PHONE_NUMBER`, `CREDIT_CARD_NUMBER`, `PERSON_NAME`).
          * Assigns a `likelihood` score to each finding.
      * **De-identification (`deidentifyContent`, `redactImage`):** Modifies data to remove or obscure sensitive parts.

  * **De-identification Techniques:**

      * **Masking (`characterMaskConfig`):** Replaces sensitive characters with a placeholder (e.g., `*`). Can specify the number of characters to mask or the masking character.
      * **Redaction (`replaceWithInfoTypeConfig` for text, `imageRedactionConfigs` for images):**
          * For text: Replaces the detected sensitive data with its `infoType` name (e.g., "test@example.com" becomes "[EMAIL\_ADDRESS]").
          * For images: Obscures the identified sensitive text within the image (e.g., by drawing a black box over it).

  * **API Request Structure (JSON):**

      * `parent`: Specifies the project and location (e.g., `projects/YOUR_PROJECT_ID/locations/global`).
      * `item` or `byteItem`: Contains the data to be processed (text string, file content, or image bytes).
      * `inspectConfig`: Defines what `infoTypes` to look for, `minLikelihood`, whether to `includeQuote` of the finding, and `limits`.
      * `deidentifyConfig`: Used with `deidentifyContent`, specifies `infoTypeTransformations` which detail how findings should be altered (e.g., masking, redaction).
      * `imageRedactionConfigs`: Used with `redactImage`, specifies which `infoTypes` to redact in an image or if all text should be redacted.

  * **Client Libraries:** Google provides client libraries (like the Node.js one used in this lab) to simplify interaction with its APIs, handling authentication and request/response formatting.

  * **Enabling APIs:** The DLP API (`dlp.googleapis.com`) and any related APIs (like Cloud KMS, if used for cryptographic de-identification) must be enabled for your project.