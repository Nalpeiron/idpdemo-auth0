# Auth0 + Zentitle2 Identity-Based Licensing Sample

This repository is a customer-facing sample that shows how to integrate Auth0 with Zentitle2 Account-Based Licensing in a .NET MAUI application.

The sample signs a user in with Auth0 and uses the returned OpenID token to activate a seat through the Zentitle2 Licensing Client. After login, the app displays the authenticated user details, the relevant token claims, and the activation summary returned by Zentitle2.

## What This Sample Demonstrates

- Auth0 login in a native .NET MAUI application
- Token claim mapping for Zentitle2 Account-Based Licensing
- Seat activation with `openIdToken` credentials
- A repeatable Auth0 setup flow using the included script

## Integration Flow

1. The user signs in through Auth0.
2. Auth0 returns an OpenID token that includes:
   - standard identity claims such as `email` and `sub`
   - the Zentitle2 entitlement group claim `urn:nalpeiron:zentitle2:claims:entitlement_group_ids`
3. The app passes that token to Zentitle2 to activate the seat.
4. Zentitle2 validates the token and returns the entitlement/activation details.

## Repository Layout

- `scripts/setup-auth0.sh` - Auth0 provisioning helper
- `appsettings.json` - configuration template
- `appsettings.Development.json` - local configuration generated and updated by the script

## Prerequisites

Before you run the sample, make sure you have:

- a Zentitle2 account
- a Zentitle2 product already created
- the Zentitle2 `TenantId`
- the Zentitle2 `LicensingApiUrl`
- the Zentitle2 `ProductId`
- an Auth0 tenant
- `bash`, `curl`, and `jq`
- .NET 10 SDK with MAUI workloads installed

You will also need an Auth0 bootstrap Machine-to-Machine application that is authorized for the Auth0 Management API with these scopes:

- `read:clients`, `create:clients`, `update:clients`
- `read:connections`, `create:connections`, `update:connections`
- `read:roles`, `create:roles`
- `read:actions`, `create:actions`, `update:actions`

## Step 1: Configure Zentitle2

For the full Zentitle2 UI process, see the Nalpeiron documentation:

[Setup Account Based Licensing with Customer Identity Providers](https://docs.nalpeiron.com/zentitle2-docs/ui-administration/configuration/account-based-licensing-identity-based-licensing/setup-account-based-licensing-with-customer-identity-providers)

For this sample, the key Zentitle2 setup is:

1. In Zentitle2, open `Administration > Configuration > Account Based Licensing`.
2. Add your Auth0 tenant as the identity provider.
3. Use these values:
   - `IDP URL`: `https://<your-auth0-domain>`
   - `Username claim`: `email`
   - `Authentication claim`: `sub`
4. Make sure the entitlement you want to test already exists and is assigned to the correct customer.
5. Add the end user under that same Zentitle2 customer with authentication type `OpenID Token`.
6. Store the Auth0 user identifier in the value used by the authentication claim. In this sample, that means the Zentitle2 account should match the Auth0 user's `sub`.
7. Assign that user access to the entitlement you want to activate.

Important notes:

- This sample uses `email` as the seat username claim and `sub` as the unique authentication claim because those are stable defaults for Auth0.
- The sample also injects the claim `urn:nalpeiron:zentitle2:claims:entitlement_group_ids` into the Auth0 token when the user has the configured Auth0 role.

## Step 2: Run the Auth0 Setup Script

From the repository root, run:

```bash
bash scripts/setup-auth0.sh
```

The script creates or updates the Auth0 objects required by this sample and writes local configuration to `appsettings.Development.json`.

During the script, you will be prompted for:

- your Auth0 tenant domain
- either an existing Auth0 Management API token or the bootstrap M2M client ID and secret
- the native application name to create or update
- the Auth0 database connection to use or create
- a namespace for custom claims
- the Zentitle2 `ProductId`
- the Zentitle2 entitlement group ID
- the Auth0 role name that should unlock that entitlement group

### What the Script Provisions in Auth0

The script:

- creates or updates a native Auth0 application
- configures the fixed callback URL `idpdemo://callback`
- creates or updates a database connection and enables it for the native application through Auth0's dedicated connection client endpoint
- creates or updates an Auth0 role used to gate the entitlement group claim
- creates, deploys, and binds a post-login Action that adds the required claims to the token
- updates `appsettings.Development.json`

The post-login Action adds:

- `urn:nalpeiron:zentitle2:claims:entitlement_group_ids`
- `<your-claim-namespace>/roles`
- `email`
- `email_verified`
- `name`
- `nickname`

## Step 3: Complete Local App Configuration

After the script finishes, open `appsettings.Development.json`.

The script fills in the Auth0 settings and some Zentitle2 fields, but you still need to provide:

- `Zentitle2.TenantId`
- `Zentitle2.LicensingApiUrl`

You should also confirm that these values are correct:

- `Zentitle2.ProductId`
- `Zentitle2.IdpUrl`

Do not put Auth0 bootstrap client secrets into `appsettings.Development.json`. The script uses them only to provision Auth0 resources.

## Step 4: Assign the Auth0 Role to Test Users

The script creates or updates an Auth0 role for the entitlement group. Assign that role to each Auth0 user who should receive the Zentitle2 entitlement group claim in their token.

Without that role assignment, the token will not contain:

- `urn:nalpeiron:zentitle2:claims:entitlement_group_ids`

## Step 5: Build and Run the App

Rebuild the app after the script finishes. The MAUI project packages `appsettings.Development.json` during build, so configuration changes are not picked up until you rebuild.

Example build command:

```bash
dotnet build IdpDemo.sln
```

Then run the sample from your preferred MAUI development environment or target platform.

## Expected Result

When setup is complete:

1. Click `Login` in the app.
2. Sign in with an Auth0 user that has the required Auth0 role and a matching Zentitle2 OpenID Token account.
3. The app should display:
   - authenticated user details
   - the token claims
   - the entitlement group claim
   - the Zentitle2 activation summary

## Troubleshooting

### The app says Auth0 is not configured

Run the setup script, verify `appsettings.Development.json`, and rebuild the app.

### Activation fails after login

Check these items:

- the Auth0 user has the required Auth0 role
- the token contains `email`, `sub`, and `urn:nalpeiron:zentitle2:claims:entitlement_group_ids`
- the Zentitle2 user is configured with authentication type `OpenID Token`
- the Zentitle2 authentication claim value matches the Auth0 `sub`
- the Zentitle2 user is assigned to the entitlement
- `Zentitle2.TenantId`, `LicensingApiUrl`, and `ProductId` are correct

## Notes for Adapting This Sample

- The callback URL is fixed to `idpdemo://callback`. If you want to change it, update both the app code and the Auth0 configuration.
- `appsettings.Development.json` is intended for local testing and environment-specific configuration.
- This sample focuses on the Auth0 + Zentitle2 integration path. It does not automate user creation in Zentitle2 or business-specific entitlement assignment workflows.
