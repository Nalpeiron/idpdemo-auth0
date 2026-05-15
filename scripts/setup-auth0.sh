#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
APPSETTINGS_TEMPLATE_PATH="${APP_ROOT}/appsettings.json"
APPSETTINGS_PATH="${APP_ROOT}/appsettings.Development.json"

CALLBACK_SCHEME="idpdemo"
CALLBACK_URL="${CALLBACK_SCHEME}://callback"
DEFAULT_SCOPE="openid profile email offline_access"

need_cmd() {
	if ! command -v "$1" >/dev/null 2>&1; then
		echo "Missing required command: $1" >&2
		exit 1
	fi
}

prompt() {
	local label="$1"
	local default_value="${2:-}"
	local value

	if [[ -n "${default_value}" ]]; then
		read -r -p "${label} [${default_value}]: " value
		echo "${value:-$default_value}"
	else
		read -r -p "${label}: " value
		echo "${value}"
	fi
}

prompt_secret() {
	local label="$1"
	local value
	read -r -s -p "${label}: " value
	echo >&2
	echo "${value}"
}

normalize_domain() {
	local value="$1"
	value="${value#https://}"
	value="${value#http://}"
	value="${value%/}"
	echo "${value}"
}

api_request() {
	local method="$1"
	local path="$2"
	local data="${3:-}"
	local url="https://${AUTH0_DOMAIN}${path}"
	local response_file
	local status_code

	response_file="$(mktemp)"

	if [[ -n "${data}" ]]; then
		status_code="$(
			curl --silent --show-error \
				-o "${response_file}" \
				-w "%{http_code}" \
				-X "${method}" \
				-H "Authorization: Bearer ${MGMT_TOKEN}" \
				-H "Content-Type: application/json" \
				-d "${data}" \
				"${url}"
		)"
	else
		status_code="$(
			curl --silent --show-error \
				-o "${response_file}" \
				-w "%{http_code}" \
				-X "${method}" \
				-H "Authorization: Bearer ${MGMT_TOKEN}" \
				"${url}"
		)"
	fi

	if [[ "${status_code}" -lt 200 || "${status_code}" -ge 300 ]]; then
		echo "HTTP ${status_code} from ${url}" >&2
		cat "${response_file}" >&2
		rm -f "${response_file}"
		return 1
	fi

	cat "${response_file}"
	rm -f "${response_file}"
}

request_json() {
	local method="$1"
	local url="$2"
	local data="${3:-}"
	local response_file
	local status_code

	response_file="$(mktemp)"

	if [[ -n "${data}" ]]; then
		status_code="$(
			curl --silent --show-error \
				-o "${response_file}" \
				-w "%{http_code}" \
				-X "${method}" \
				-H "Content-Type: application/json" \
				-d "${data}" \
				"${url}"
		)"
	else
		status_code="$(
			curl --silent --show-error \
				-o "${response_file}" \
				-w "%{http_code}" \
				-X "${method}" \
				"${url}"
		)"
	fi

	if [[ "${status_code}" -lt 200 || "${status_code}" -ge 300 ]]; then
		echo "HTTP ${status_code} from ${url}" >&2
		cat "${response_file}" >&2
		rm -f "${response_file}"
		return 1
	fi

	cat "${response_file}"
	rm -f "${response_file}"
}

create_or_update_action() {
	local existing_action_id="$1"
	local create_payload="$2"
	local update_payload="$3"

	if [[ -n "${existing_action_id}" ]]; then
		api_request PATCH "/api/v2/actions/actions/${existing_action_id}" "${update_payload}" >/dev/null
		echo "${existing_action_id}"
	else
		api_request POST "/api/v2/actions/actions" "${create_payload}" | jq -r '.id'
	fi
}

need_cmd curl
need_cmd jq

if [[ ! -f "${APPSETTINGS_TEMPLATE_PATH}" ]]; then
	echo "Expected appsettings.json template at ${APPSETTINGS_TEMPLATE_PATH}" >&2
	exit 1
fi

if [[ ! -f "${APPSETTINGS_PATH}" ]]; then
	cp "${APPSETTINGS_TEMPLATE_PATH}" "${APPSETTINGS_PATH}"
fi

CURRENT_PRODUCT_ID="$(jq -r '.Zentitle2.ProductId // empty' "${APPSETTINGS_PATH}")"

cat <<'EOF'
This script provisions the Auth0 pieces required by the MAUI app and updates appsettings.Development.json.

You will need a bootstrap Machine-to-Machine application in Auth0 with access to the Auth0 Management API.
Create it in Auth0 Dashboard:
  Applications > Applications > Create Application > Machine to Machine Applications
Then authorize it for "Auth0 Management API" with scopes that cover:
  read:clients create:clients update:clients
  read:connections create:connections update:connections
  read:resource_servers create:resource_servers update:resource_servers
  read:roles create:roles
  read:actions create:actions update:actions

For Zentitle2, the script will configure these token mappings:
  Username claim: email
  Authentication claim: sub
  Entitlement claim: urn:nalpeiron:zentitle2:claims:entitlement_group_ids

The MAUI app is fixed to the callback URL:
  idpdemo://callback

If you already have a valid Auth0 Management API token, you can paste it and skip the bootstrap client credential step.
EOF

echo

AUTH0_DOMAIN="$(normalize_domain "$(prompt "Auth0 tenant domain" "your-tenant.us.auth0.com")")"
USE_EXISTING_MGMT_TOKEN="$(prompt "Do you already have an Auth0 Management API token? (y/N)" "N")"
BOOTSTRAP_CLIENT_ID=""
BOOTSTRAP_CLIENT_SECRET=""
MGMT_TOKEN="${AUTH0_MGMT_TOKEN:-}"

if [[ "${USE_EXISTING_MGMT_TOKEN}" =~ ^[Yy]$ ]]; then
	if [[ -z "${MGMT_TOKEN}" ]]; then
		MGMT_TOKEN="$(prompt_secret "Paste the Auth0 Management API token")"
	fi
else
	BOOTSTRAP_CLIENT_ID="$(prompt "Bootstrap Management API client ID")"
	BOOTSTRAP_CLIENT_SECRET="$(prompt_secret "Bootstrap Management API client secret")"
fi

APPLICATION_NAME="$(prompt "Native application name" "IdpDemo Native")"
CONNECTION_NAME="$(prompt "Database connection name to use/create" "Username-Password-Authentication")"
CLAIM_NAMESPACE="$(prompt "Namespace for custom claims" "https://idpdemo.example.com/auth0")"
PRODUCT_ID="$(
	if [[ -n "${CURRENT_PRODUCT_ID}" ]]; then
		prompt "Zentitle2 product ID (also used as Auth0 API audience)" "${CURRENT_PRODUCT_ID}"
	else
		prompt "Zentitle2 product ID (also used as Auth0 API audience)"
	fi
)"
ENTITLEMENT_GROUP_ID="$(prompt "Zentitle2 entitlementGroupId")"
ROLE_NAME="$(prompt "Role name that unlocks the entitlement group" "zentitle2-entitlement-${ENTITLEMENT_GROUP_ID}")"

CLAIM_NAMESPACE="${CLAIM_NAMESPACE%/}"
IDP_URL="https://${AUTH0_DOMAIN}"
ENTITLEMENT_CLAIM="urn:nalpeiron:zentitle2:claims:entitlement_group_ids"
ROLES_CLAIM="${CLAIM_NAMESPACE}/roles"

echo
if [[ -z "${MGMT_TOKEN}" ]]; then
	echo "Requesting Auth0 Management API token..."

	TOKEN_RESPONSE="$(
		request_json POST "https://${AUTH0_DOMAIN}/oauth/token" "$(jq -n \
			--arg client_id "${BOOTSTRAP_CLIENT_ID}" \
			--arg client_secret "${BOOTSTRAP_CLIENT_SECRET}" \
			--arg audience "https://${AUTH0_DOMAIN}/api/v2/" \
			'{
				client_id: $client_id,
				client_secret: $client_secret,
				audience: $audience,
				grant_type: "client_credentials"
			}')"
	)" || {
		cat <<EOF >&2

Failed to acquire a Management API access token.

Most common causes:
  1. The client ID / client secret belong to the wrong application.
     Use a Machine-to-Machine application, not the native app created for MAUI login.
  2. The Machine-to-Machine application is not authorized for "Auth0 Management API".
     In Auth0 Dashboard go to Applications > APIs > Auth0 Management API > Machine to Machine Applications
     and authorize your bootstrap app there.
  3. The client secret was rotated and the old secret is being used.
  4. The tenant domain is wrong.
     For this tenant it should look like: ${AUTH0_DOMAIN}

Auth0 reference:
  https://auth0.com/docs/secure/tokens/access-tokens/management-api-access-tokens/get-management-api-access-tokens-for-production
  https://auth0.com/docs/get-started/auth0-overview/create-applications/machine-to-machine-apps
EOF
		exit 1
	}

	MGMT_TOKEN="$(jq -r '.access_token // empty' <<<"${TOKEN_RESPONSE}")"
	if [[ -z "${MGMT_TOKEN}" ]]; then
		echo "Auth0 did not return an access_token." >&2
		echo "${TOKEN_RESPONSE}" >&2
		exit 1
	fi
else
	echo "Using existing Management API token from input or AUTH0_MGMT_TOKEN."
fi

echo "Ensuring native Auth0 application exists..."

EXISTING_CLIENT="$(
	api_request GET "/api/v2/clients?fields=client_id,name,app_type,callbacks,allowed_logout_urls&include_fields=true" \
	| jq -c --arg name "${APPLICATION_NAME}" '[.[] | select(.name == $name and .app_type == "native")] | first'
)"

CLIENT_PAYLOAD="$(jq -n \
	--arg name "${APPLICATION_NAME}" \
	--arg callback "${CALLBACK_URL}" \
	'{
		name: $name,
		app_type: "native",
		oidc_conformant: true,
		token_endpoint_auth_method: "none",
		grant_types: ["authorization_code", "refresh_token"],
		callbacks: [$callback],
		allowed_logout_urls: [$callback]
	}')"

if [[ "${EXISTING_CLIENT}" != "null" ]]; then
	CLIENT_ID="$(jq -r '.client_id' <<<"${EXISTING_CLIENT}")"
	api_request PATCH "/api/v2/clients/${CLIENT_ID}" "${CLIENT_PAYLOAD}" >/dev/null
else
	CLIENT_ID="$(api_request POST "/api/v2/clients" "${CLIENT_PAYLOAD}" | jq -r '.client_id')"
fi

echo "Ensuring Auth0 API exists for the Zentitle2 product audience..."

RESOURCE_SERVER_NAME="Zentitle2 Product ${PRODUCT_ID}"
EXISTING_RESOURCE_SERVER="$(
	api_request GET "/api/v2/resource-servers?fields=id,name,identifier&include_fields=true" \
	| jq -c --arg identifier "${PRODUCT_ID}" '[.[] | select(.identifier == $identifier)] | first'
)"

RESOURCE_SERVER_CREATE_PAYLOAD="$(jq -n \
	--arg name "${RESOURCE_SERVER_NAME}" \
	--arg identifier "${PRODUCT_ID}" \
	'{
		name: $name,
		identifier: $identifier,
		signing_alg: "RS256",
		allow_offline_access: true,
		skip_consent_for_verifiable_first_party_clients: true,
		token_dialect: "access_token"
	}')"

RESOURCE_SERVER_UPDATE_PAYLOAD="$(jq -n \
	--arg name "${RESOURCE_SERVER_NAME}" \
	'{
		name: $name,
		signing_alg: "RS256",
		allow_offline_access: true,
		skip_consent_for_verifiable_first_party_clients: true,
		token_dialect: "access_token"
	}')"

if [[ "${EXISTING_RESOURCE_SERVER}" == "null" ]]; then
	RESOURCE_SERVER_ID="$(
		api_request POST "/api/v2/resource-servers" "${RESOURCE_SERVER_CREATE_PAYLOAD}" | jq -r '.id'
	)"
else
	RESOURCE_SERVER_ID="$(jq -r '.id' <<<"${EXISTING_RESOURCE_SERVER}")"
	api_request PATCH "/api/v2/resource-servers/${RESOURCE_SERVER_ID}" "${RESOURCE_SERVER_UPDATE_PAYLOAD}" >/dev/null
fi

echo "Ensuring database connection exists and is enabled for the native application..."

EXISTING_CONNECTION="$(
	api_request GET "/api/v2/connections?strategy=auth0&fields=id,name&include_fields=true" \
	| jq -c --arg name "${CONNECTION_NAME}" '[.[] | select(.name == $name)] | first'
)"

if [[ "${EXISTING_CONNECTION}" == "null" ]]; then
	CONNECTION_PAYLOAD="$(jq -n \
		--arg name "${CONNECTION_NAME}" \
		'{
			name: $name,
			strategy: "auth0",
			options: {
				passwordPolicy: "good",
				disable_signup: false,
				requires_username: false
			}
		}')"
	EXISTING_CONNECTION="$(api_request POST "/api/v2/connections" "${CONNECTION_PAYLOAD}")"
fi

CONNECTION_ID="$(jq -r '.id' <<<"${EXISTING_CONNECTION}")"
api_request PATCH "/api/v2/connections/${CONNECTION_ID}/clients" "$(jq -n --arg client_id "${CLIENT_ID}" '[{ client_id: $client_id, status: true }]')" >/dev/null

echo "Ensuring role exists..."

EXISTING_ROLE="$(
	api_request GET "/api/v2/roles?per_page=100" \
	| jq -c --arg name "${ROLE_NAME}" '[.[] | select(.name == $name)] | first'
)"

if [[ "${EXISTING_ROLE}" == "null" ]]; then
	ROLE_ID="$(
		api_request POST "/api/v2/roles" "$(jq -n \
			--arg name "${ROLE_NAME}" \
			--arg entitlement_group_id "${ENTITLEMENT_GROUP_ID}" \
			'{
				name: $name,
				description: ("Grants Zentitle2 entitlement group " + $entitlement_group_id)
			}')" | jq -r '.id'
	)"
else
	ROLE_ID="$(jq -r '.id' <<<"${EXISTING_ROLE}")"
fi

ACTION_NAME="Inject Zentitle2 Entitlement Claims"
ACTION_CODE="$(cat <<EOF
/**
 * Adds Zentitle2 claims and selected profile claims to Auth0-issued tokens.
 */
exports.onExecutePostLogin = async (event, api) => {
  const namespace = '${CLAIM_NAMESPACE}';
  const entitlementGroupId = '${ENTITLEMENT_GROUP_ID}';
  const requiredRoleName = '${ROLE_NAME}';
  const roles = event.authorization?.roles || [];
  const email = event.user.email;
  const name = event.user.name || event.user.nickname;

  api.idToken.setCustomClaim(\`\${namespace}/roles\`, roles);
  api.accessToken.setCustomClaim(\`\${namespace}/roles\`, roles);

  if (email) {
    api.accessToken.setCustomClaim('email', email);
  }

  if (typeof event.user.email_verified === 'boolean') {
    api.accessToken.setCustomClaim('email_verified', event.user.email_verified);
  }

  if (name) {
    api.accessToken.setCustomClaim('name', name);
  }

  if (event.user.nickname) {
    api.accessToken.setCustomClaim('nickname', event.user.nickname);
  }

  if (roles.includes(requiredRoleName)) {
    api.idToken.setCustomClaim('${ENTITLEMENT_CLAIM}', entitlementGroupId);
    api.accessToken.setCustomClaim('${ENTITLEMENT_CLAIM}', entitlementGroupId);
  }
};
EOF
)"

echo "Creating or updating the post-login Action..."

EXISTING_ACTION_ID="$(
	api_request GET "/api/v2/actions/actions?triggerId=post-login" \
	| jq -r --arg name "${ACTION_NAME}" '[.actions[]? | select(.name == $name)] | first | .id // empty'
)"

ACTION_CREATE_PAYLOAD="$(jq -n \
	--arg name "${ACTION_NAME}" \
	--arg code "${ACTION_CODE}" \
	'{
		name: $name,
		supported_triggers: [{ id: "post-login", version: "v3" }],
		runtime: "node18",
		code: $code,
		deploy: false
	}')"

ACTION_UPDATE_PAYLOAD="$(jq -n \
	--arg name "${ACTION_NAME}" \
	--arg code "${ACTION_CODE}" \
	'{
		name: $name,
		supported_triggers: [{ id: "post-login", version: "v3" }],
		runtime: "node18",
		code: $code
	}')"

ACTION_ID="$(create_or_update_action "${EXISTING_ACTION_ID}" "${ACTION_CREATE_PAYLOAD}" "${ACTION_UPDATE_PAYLOAD}")"
api_request POST "/api/v2/actions/actions/${ACTION_ID}/deploy" "{}" >/dev/null

echo "Binding the Action into the post-login flow..."

CURRENT_BINDINGS="$(api_request GET "/api/v2/actions/triggers/post-login/bindings")"
UPDATED_BINDINGS="$(
	jq -n \
		--arg action_id "${ACTION_ID}" \
		--arg display_name "${ACTION_NAME}" \
		--argjson existing "${CURRENT_BINDINGS}" '
		{
			bindings: (
				[
					($existing.bindings[]? |
						select((.ref.value // .action.id) != $action_id) |
						{
							ref: {
								type: (.ref.type // "action_id"),
								value: (.ref.value // .action.id)
							},
							display_name: .display_name
						})
				] + [
					{
						ref: {
							type: "action_id",
							value: $action_id
						},
						display_name: $display_name
					}
				]
			)
		}'
)"
api_request PATCH "/api/v2/actions/triggers/post-login/bindings" "${UPDATED_BINDINGS}" >/dev/null

echo "Updating appsettings.Development.json..."

tmp_file="$(mktemp)"
jq \
	--arg domain "${AUTH0_DOMAIN}" \
	--arg client_id "${CLIENT_ID}" \
	--arg callback "${CALLBACK_URL}" \
	--arg scope "${DEFAULT_SCOPE}" \
	--arg claim_namespace "${CLAIM_NAMESPACE}" \
	--arg entitlement_claim "${ENTITLEMENT_CLAIM}" \
	--arg roles_claim "${ROLES_CLAIM}" \
	--arg role_name "${ROLE_NAME}" \
	--arg idp_url "${IDP_URL}" \
	--arg product_id "${PRODUCT_ID}" \
	'
	.Auth0.Domain = $domain |
	.Auth0.ClientId = $client_id |
	.Auth0.RedirectUri = $callback |
	.Auth0.PostLogoutRedirectUri = $callback |
	.Auth0.Scope = $scope |
	.Auth0.ClaimNamespace = $claim_namespace |
	.Auth0.EntitlementGroupIdClaim = $entitlement_claim |
	.Auth0.RolesClaim = $roles_claim |
	.Auth0.RequiredRoleName = $role_name |
	.Zentitle2.IdpUrl = $idp_url |
	.Zentitle2.ProductId = $product_id |
	.Zentitle2.UsernameClaim = "email" |
	.Zentitle2.AuthenticationClaim = "sub" |
	.Zentitle2.EntitlementGroupIdClaim = $entitlement_claim
	' "${APPSETTINGS_PATH}" > "${tmp_file}"
mv "${tmp_file}" "${APPSETTINGS_PATH}"

cat <<EOF

Auth0 provisioning complete.

Created or updated:
  Native application client id: ${CLIENT_ID}
  Auth0 API audience: ${PRODUCT_ID}
  Database connection: ${CONNECTION_NAME}
  Role: ${ROLE_NAME}
  Post-login Action: ${ACTION_NAME}

Zentitle2 values to enter in Administration > Configuration > Account-Based Licensing:
  IDP URL: ${IDP_URL}
  Username claim: email
  Authentication claim: sub

Custom claims added to the token when the role is assigned:
  ${ENTITLEMENT_CLAIM}
  ${ROLES_CLAIM}

Additional profile claims added to the access token when available:
  email
  email_verified
  name
  nickname

Next steps:
  1. Assign the Auth0 role "${ROLE_NAME}" to each user who should receive entitlement group ${ENTITLEMENT_GROUP_ID}.
  2. Rebuild and run the MAUI app so the packaged appsettings.Development.json is refreshed.
  3. Click Login in the app. The access token should now include aud=${PRODUCT_ID} and the entitlement group claim.
EOF
