# Securing Cloud Applications with Identity-Aware Proxy (IAP) using Zero-Trust

## Overview

This lab demonstrates how to apply the Zero Trust security model to web applications using Google Cloud's Identity-Aware Proxy (IAP). You will deploy a sample Python application to App Engine, secure it with IAP by controlling access based on user identity, and then modify the application to retrieve and display user identity information provided by IAP.

## Learning Objectives

* Deploy a simple Python application to Google App Engine.
* Enable Identity-Aware Proxy (IAP) to restrict access to the deployed application.
* Understand how to obtain user identity information within an application protected by IAP.

## Prerequisites

* Basic knowledge of Python programming.

## Scenario

You will build and deploy a minimal web application using Google App Engine. After initial deployment, you will use Identity-Aware Proxy (IAP) to control access, allowing only authorized users. Finally, the application will be updated to display identity information provided by IAP about the authenticated user.

The application will:
1.  Display a simple welcome page.
2.  Be secured by IAP.
3.  Access and display user identity information (email, persistent ID) passed by IAP.

## Task 1: Deploy the Application and Protect it Using IAP

This task involves deploying a basic "Hello, World" Python Flask application to App Engine Standard and then enabling IAP to control access.

**1. Download and Review Application Code**

* Download sample code from GitHub:
    ```bash
    git clone [https://github.com/googlecodelabs/user-authentication-with-iap.git](https://github.com/googlecodelabs/user-authentication-with-iap.git)
    cd user-authentication-with-iap
    ```
* Navigate to the initial application directory:
    ```bash
    cd 1-HelloWorld
    ```
* **Key Files:**
    * `main.py`: A simple Flask application.
    * `templates/index.html`: Basic HTML for the welcome page.
    * `templates/privacy.html`: Skeletal privacy policy.
    * `requirements.txt`: Lists Python dependencies (e.g., Flask).
    * `app.yaml`: App Engine configuration file, specifying the runtime (e.g., Python 3.8, updated to Python 3.9 in the lab).
* You can view file contents using `cat` or the Cloud Shell Editor.
    ```bash
    cat main.py
    cat app.yaml
    ```

**2. Deploy the Application to App Engine**

* **Create the App Engine application** within your project (if not already created). Choose a region.
    ```bash
    # Replace REGION with the desired region, e.g., us-central
    gcloud app create --project=$(gcloud config get-value project) --region=REGION
    ```
    Enter `Y` to continue if prompted. Authorize the API call if necessary.
* **Update runtime in `app.yaml`:** The lab specifies updating the runtime. Open `1-HelloWorld/app.yaml` in the Cloud Shell Editor and change `runtime: python38` (or similar) to:
    ```yaml
    runtime: python39
    ```
* **Deploy the application:**
    ```bash
    gcloud app deploy
    ```
    Enter `Y` to continue if prompted. This may take a few minutes.
* **Browse the deployed application:**
    ```bash
    gcloud app browse
    ```
    At this point, the application is publicly accessible.

**3. Restrict Access with IAP**

* **Enable IAP API:**
    * Navigate to **Navigation Menu > View all products > Security > Identity-Aware Proxy**.
    * Click **Enable API**. Then click **Go To Identity-Aware Proxy**.
* **Configure OAuth Consent Screen:**
    1.  If prompted, click **Configure Consent Screen**.
    2.  On the "OAuth consent screen" page: User Type: Select **Internal**. Click **CREATE**.
    3.  App Information:
        * **App name:** `IAP Example`
        * **User support email:** Your Qwiklabs student email.
    4.  Developer contact information: Enter an email address (e.g., your Qwiklabs student email).
    5.  Click **SAVE AND CONTINUE** through the Scopes and Optional Info sections.
    6.  On the Summary page, click **BACK TO DASHBOARD**.
* **Obtain Authorized Domain and Configure OAuth Client ID:**
    * Get your App Engine app's default hostname (this will be your `AUTH_DOMAIN` base):
        ```bash
        # In Cloud Shell
        # The output from 'gcloud app browse' after deployment shows this.
        # Or construct it: PROJECT_ID.REGION_ID.r.appspot.com (e.g., your-project-id.uc.r.appspot.com)
        # The lab uses:
        export AUTH_DOMAIN=$(gcloud config get-value project).uc.r.appspot.com
        echo $AUTH_DOMAIN # Note this domain
        ```
    * The IAP redirect URI will be `https://[AUTH_DOMAIN]/_gcp_iap/handle_login`.
    * Navigate to **APIs & Services > Credentials**.
    * Click **+ CREATE CREDENTIALS** > **OAuth client ID**.
    * **Application type:** `Web application`.
    * **Name:** `IAP Web App Client` (or similar).
    * Under **Authorized redirect URIs**, click **+ ADD URI**.
    * Enter the IAP redirect URI: `https://[YOUR_AUTH_DOMAIN]/_gcp_iap/handle_login` (substitute `[YOUR_AUTH_DOMAIN]` with the value from the `echo` command).
    * Click **CREATE**.

* **Enable IAP for the App Engine Application:**
    1.  Navigate back to **Identity-Aware Proxy**.
    2.  Refresh the page if your App Engine app isn't listed.
    3.  Find your App Engine application. Click the toggle switch in the **IAP** column to **ON**.
    4.  Confirm if prompted.

* **Verify Restricted Access:**
    * Access your App Engine app's URL.
    * You should be redirected for Google sign-in. After signing in, an "You don't have access" error should appear.

**4. Allow Members to Access Application**

* On the **Identity-Aware Proxy** page:
    1.  Select the checkbox next to your App Engine application.
    2.  In the right-hand info panel, click **ADD PRINCIPAL**.
    3.  **New principals:** Enter your Qwiklabs student username.
    4.  **Select a role:** Choose `Cloud IAP` > `IAP-secured Web App User`.
    5.  Click **SAVE**.

**5. Verify Access is Restored**

* Reload your App Engine application's URL. You should now see the "Hello, World" page.
* **If you still see "You don't have access":**
    * Clear the IAP login cookie by navigating to: `https://[YOUR_APP_ENGINE_APP_URL]/_gcp_iap/clear_login_cookie`
    * Sign in again, ensuring you use "Use another account" and re-enter your lab credentials.

## Task 2: Access User Identity Information

This task updates the application to read and display user identity information provided by IAP.

**1. Deploy Updated Application Code**

* Navigate to the updated application directory:
    ```bash
    cd ~/user-authentication-with-iap/2-HelloUser
    ```
* **Update `app.yaml` runtime (if necessary):** Ensure `runtime: python39` is set.
* Deploy the new version:
    ```bash
    gcloud app deploy
    ```
    Enter `Y` to continue if prompted.
* Browse the updated application:
    ```bash
    gcloud app browse
    ```
    Refresh the page. It should now display your email and a persistent user ID.

**2. Examine Application File Changes**

* `main.py` (in `2-HelloUser`):
    * Code is added to read the IAP headers:
        ```python
        user_email = request.headers.get('X-Goog-Authenticated-User-Email')
        user_id = request.headers.get('X-Goog-Authenticated-User-ID')
        ```
    * These values are passed to the template:
        ```python
        page = render_template('index.html', email=user_email, id=user_id)
        ```
* `templates/index.html` (in `2-HelloUser`):
    * The template is updated to display the passed values:
        ```html
        Hello, {{ email }}! Your persistent ID is {{ id }}.
        ```

## Key Concepts and Important Points

* **Zero Trust Security Model:**
    * Operates on the principle of "never trust, always verify."
    * Access is granted based on verified identity, device, location, and other contextual factors for every request, not just network perimeter.
    * Aims to provide precise security and lower risk for each application individually.

* **Identity-Aware Proxy (IAP):**
    * A core Google Cloud service for implementing Zero Trust access to web applications (App Engine, Compute Engine, GKE) and VM instances (for TCP forwarding like SSH).
    * Acts as a policy enforcement engine, ensuring every access request is authenticated and authorized before reaching the application.
    * Replaces the need for VPNs or relying solely on network firewalls/ACLs for application access control.

* **IAP for App Engine:**
    * When enabled for an App Engine application, IAP intercepts all incoming requests.
    * It forces users to authenticate with their Google identity.
    * Access is then granted based on IAM permissions (specifically, the `IAP-secured Web App User` role).

* **OAuth Consent Screen:**
    * A mandatory one-time setup per project when using IAP or other services that require OAuth 2.0.
    * Defines how your application is presented to users during the Google sign-in flow (app name, support email).
    * Configures authorized redirect URIs, which for IAP include a specific endpoint (`/_gcp_iap/handle_login`) on your application's domain.

* **OAuth 2.0 Client ID for Web Applications:**
    * Needs to be configured with the correct "Authorized redirect URIs" for IAP to function correctly. The redirect URI for IAP is `https://[YOUR_APP_URL]/_gcp_iap/handle_login`.

* **IAP-Provided HTTP Headers:**
    * Once a user is authenticated, IAP passes verified identity information to the backend application via HTTP headers.
    * `X-Goog-Authenticated-User-Email`: Contains the user's email address, prefixed by `accounts.google.com:`.
    * `X-Goog-Authenticated-User-ID`: Contains a persistent, unique Google ID for the user, prefixed by `accounts.google.com:`.
    * Applications can securely read these headers to identify the user and personalize the experience or apply further in-app authorization.
    * These headers are stripped from external requests and can only be set by IAP, making them trustworthy.

* **IAM Role for IAP Access:**
    * The `roles/iap.securedWebAppUser` (Cloud IAP > IAP-secured Web App User) role is granted to users or groups in IAM to allow them to access an IAP-protected web application.

* **IAP Login Cookie and Clearing:**
    * IAP uses cookies to manage user sessions.
    * If access changes aren't reflected immediately, it might be due to a cached session.
    * Appending `/_gcp_iap/clear_login_cookie` to the application's URL forces IAP to clear its session cookie for that browser and re-authenticate/re-authorize the user.

* **App Engine Deployment:**
    * `gcloud app create --region=REGION`: Initializes App Engine in a project for a specific region.
    * `app.yaml`: Configuration file defining runtime, environment variables, scaling, and other settings for App Engine applications.
    * `gcloud app deploy`: Deploys the application code and configuration to App Engine.
    * `gcloud app browse`: Opens the deployed application in a web browser.