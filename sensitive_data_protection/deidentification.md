# Creating a De-identified Copy of Data

## Overview

Google Cloud Sensitive Data Protection is a service for discovering, classifying, and protecting sensitive information. This lab demonstrates using the De-identify (DeID) Findings Action to create redacted and de-identified copies of data in Cloud Storage.

An input Cloud Storage bucket contains sample data, and an output bucket receives the redacted data.

## Objectives of the Lab

*   Create DLP de-identification templates for structured and unstructured data.
*   Configure a DLP Inspection Job Trigger with the De-identify Findings Action enabled.
*   Create a DLP Inspection Job.
*   View results of the inspection job and the new de-identified files in Cloud Storage.

## Task 1: Create De-identify Templates

### Template for Unstructured Data

*   **Template type:** De-identify (remove sensitive data)
*   **Data transformation type:** InfoType
*   **Transformation Rule:** Replace with infoType name.
*   **InfoTypes to transform:** Any detected infoTypes not specified in other rules.

### Template for Structured Data

*   **Template type:** De-identify (remove sensitive data)
*   **Data transformation type:** Record
*   **Transformation Rules:**
    *   **Rule 1:**
        *   **Field names:** `ssn`, `ccn`, `email`, `vin`, `id`, `agent_id`, `user_id`
        *   **Transformation type:** Primitive field transformation
        *   **Transformation method:** Replace (replaces cell contents for matching fields)
    *   **Rule 2:**
        *   **Field name:** `message`
        *   **Transformation type:** Match on infoType
        *   **Transformation Method:** Replace with infoType name
        *   **InfoTypes to transform:** Any detected infoTypes not specified in other rules (applies infoType inspection/redaction to files with a `message` field).

## Task 2: Create a DLP Inspection Job Trigger

*   Configure input data (Cloud Storage bucket URL, sampling 100%).
*   Configure detection (default settings).
*   Enable **Make a de-identify copy** action.
*   Specify the unstructured and structured de-identify template paths.
*   Specify the Cloud Storage output location (the second bucket created in the lab setup).
*   Schedule the job (e.g., Weekly).
*   Create the trigger.

## Task 3: Run DLP Inspection and Review Results

*   Find the created Job Trigger under **Inspection** > **Job Triggers**.
*   Select the trigger and click **Run Now**.
*   Monitor the triggered job instance until it shows **Done**.
*   Review findings and job results.
*   View de-identified output in the specified Cloud Storage output bucket by clicking the bucket link on the job results page.
*   Explore folders and files to see redacted data (e.g., redacted images).

## Important Points

*   Sensitive Data Protection is a managed service for discovering, classifying, and protecting sensitive data.
*   De-identification allows creating redacted or transformed copies of data.
*   De-identification templates define how data should be transformed (e.g., replacing with infoType name, replacing field contents).
*   Separate templates can be created for unstructured (InfoType based) and structured (Record based) data.
*   DLP Inspection Job Triggers can be configured to scan Cloud Storage buckets periodically.
*   The De-identify Findings Action within a job trigger automates the de-identification process, writing output to a specified location.
*   The lab uses temporary credentials and requires an Incognito browser window to avoid conflicts with personal accounts.
*   Template paths follow the format `projects//locations/global/deidentifyTemplates/<template_id>`.
*   The de-identified output is written to a separate Cloud Storage bucket.
*   Different transformation methods (Replace, Replace with infoType name, etc.) can be used based on requirements. 