# Protect Cloud Traffic


## Task 1: Deploy a provided web application in `us-east1` to Google Cloud

This task involves deploying a sample Python "Hello, World" application to App Engine.

**Steps & `gcloud` CLI Commands:**

1.  **Activate Cloud Shell** from the Google Cloud Console.
2.  **Clone the sample code repository:**
    ```bash
    git clone https://github.com/GoogleCloudPlatform/python-docs-samples.git
    ```
3.  **Navigate to the application directory:**
    ```bash
    cd python-docs-samples/appengine/standard_python3/hello_world/
    ```
4.  **Create the App Engine application** in your project, specifying the `us-east1` region:
    ```bash
    gcloud app create --region=us-east1
    ```
      * If prompted to enable APIs or confirm, type `Y` and press Enter.
5.  **Deploy the application:**
    ```bash
    gcloud app deploy
    ```
      * If prompted to confirm, type `Y` and press Enter. Wait for the deployment to complete.
6.  **View the deployed application** to confirm it's working (optional, but good practice):
    ```bash
    gcloud app browse
    ```
    This will open the application URL in a new browser tab.

-----

## Task 2: Configure OAuth Consent for the web application deployed

This task sets up the OAuth consent screen, which is necessary for IAP to function. It defines what users see when they're asked to grant permissions.

**Steps (Primarily UI as it's a one-time setup with specific informational fields):**

1.  In the Google Cloud Console, navigate to **APIs & Services \> OAuth consent screen**.
2.  You'll be asked to choose a **User Type**. For this lab, select **External**.
3.  Click **CREATE**.
4.  **App information:**
      * **App name:** Enter a descriptive name, e.g., "My IAP Protected App".
      * **User support email:** Select your Qwiklabs student email address from the dropdown.
      * **(Optional)** App logo, Application home page, etc. (not required for this lab).
5.  **Developer contact information:**
      * **Email addresses:** Enter your Qwiklabs student email address.
6.  Click **SAVE AND CONTINUE**.
7.  **Scopes:** Click **SAVE AND CONTINUE** (no specific scopes need to be added for this basic IAP setup).
8.  **Test users:** Click **SAVE AND CONTINUE** (you will add IAP users later through IAP's IAM controls, not here).
9.  **Summary:** Review the summary and click **BACK TO DASHBOARD**.
      * Your consent screen is now configured. For "External" apps, it might initially be in a "Testing" publishing status. This is usually fine for lab purposes.

-----

## Task 3: Configure the deployed web application to utilize IAP to protect traffic

This task enables IAP for your App Engine application and tests the initial restricted access.

**Steps & `gcloud` CLI Commands:**

1.  **Enable the IAP API** in your project:
    ```bash
    gcloud services enable iap.googleapis.com
    ```
2.  **Enable IAP for your App Engine application:**
      * This step is most straightforwardly done via the UI after the OAuth consent screen is configured, as it involves linking the OAuth configuration to the App Engine resource through IAP.
      * **UI Steps:**
        1.  In the Google Cloud Console, navigate to **Security \> Identity-Aware Proxy**.
        2.  If prompted about configuring your OAuth consent screen (even if you just did), you might need to refresh or ensure the previous step is fully saved.
        3.  You should see your App Engine application listed under "HTTPS Resources".
        4.  Find your App Engine app in the list. In the **IAP** column, click the toggle switch to turn it **ON**.
        5.  A "Turn on IAP" window will appear. It might ask you to confirm firewall settings or OAuth client creation. Review and click **TURN ON**. This process typically creates the necessary OAuth client ID that IAP will use for your App Engine app.
3.  **Verify access (Owner user):**
      * Open the URL of your App Engine application (you can get it again with `gcloud app browse`).
      * You will be redirected to a Google sign-in page. Sign in with your Qwiklabs **Owner** user account (the one you are currently using in the console).
      * You *should* be able to access the application because, by default, project owners often have implicit IAP access or are easily added. However, the lab wants you to verify this explicitly.
4.  **Verify restricted access (Tester user):**
      * Open a new **Incognito window** in your browser (or a different browser profile).
      * Access the URL of your App Engine application.
      * When prompted to sign in, use the credentials for the **Tester** user account provided by the lab.
      * You should see an error page stating "You don't have access" or similar. This confirms IAP is now protecting the app and the Tester account is not yet authorized.

-----

## Task 4: Authorize the test account access to the App Engine application

This task grants the **Tester** user account permission to access the IAP-protected application.

**Steps & `gcloud` CLI Commands:**

1.  **Add the Tester account as a principal with the "IAP-secured Web App User" role:**
      * You need the email address of the **Tester** user account.
      * You need your **Project ID**. You can get it with `gcloud config get-value project`.
      * **`gcloud` CLI command:**
        ```bash
        # Replace YOUR_PROJECT_ID with your actual project ID
        # Replace TESTER_USER_EMAIL with the Tester user's email address
        gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
            --member="user:TESTER_USER_EMAIL" \
            --role="roles/iap.securedWebAppUser"
        ```
        *Note: This command grants the role at the project level. IAP for App Engine often checks project-level bindings for this role. Alternatively, you can grant it specifically on the IAP resource itself via the IAP console.*
      * **UI Steps (alternative, more granular):**
        1.  In the Google Cloud Console, navigate to **Security \> Identity-Aware Proxy**.
        2.  Select the checkbox next to your App Engine application.
        3.  In the right-hand info panel, click **ADD PRINCIPAL** (or "Grant Access").
        4.  **New principals:** Enter the email address of the **Tester** user account.
        5.  **Select a role:** Choose `Cloud IAP` \> `IAP-secured Web App User`.
        6.  Click **SAVE**.
2.  **Verify access (Tester user):**
      * Go back to the **Incognito window** where you were logged in as the **Tester** user (or open a new one and log in as Tester).
      * Access the URL of your App Engine application again.
      * You should now be able to see the "Hello, World\!" application without any permission issues. If you still see an error, try clearing the IAP login cookie by appending `/_gcp_iap/clear_login_cookie` to your app's URL (e.g., `https://YOUR_PROJECT_ID.appspot.com/_gcp_iap/clear_login_cookie`) and then sign in again.