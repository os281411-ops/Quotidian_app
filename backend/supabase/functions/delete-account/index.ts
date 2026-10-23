// =====================================================================
// delete-account (checklist 30b)
//
// Deletes the signed-in person's Bookclub account and, first, asks Apple
// to revoke Quotidian's Sign in with Apple access (Apple requires this
// for apps that offer account deletion).
//
// The app sends a fresh `authorizationCode` from Sign in with Apple. We
// exchange it for a token, revoke that token, then delete the account
// using the person's own session (the same delete_my_account() function
// the app used before). If revoking fails, the account is still deleted.
//
// Secrets (Supabase dashboard → Edge Functions → Secrets), per project:
//   APPLE_TEAM_ID      your Apple Developer Team ID (R5Q96X7FAY)
//   APPLE_KEY_ID       the Sign in with Apple key's ID (10 characters)
//   APPLE_PRIVATE_KEY  the whole contents of the .p8 key file
//   APPLE_CLIENT_ID    the app's bundle ID: com.oliverscott.Quotidian (live)
//                      or com.oliverscott.Quotidian.dev (dev project)
// SUPABASE_URL and SUPABASE_ANON_KEY are provided automatically.
// =====================================================================

import { createClient } from "npm:@supabase/supabase-js@2";
import { importPKCS8, SignJWT } from "npm:jose@5";

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "Use POST" }, 405);

  const authHeader = req.headers.get("Authorization") ?? "";
  const accessToken = authHeader.replace(/^Bearer\s+/i, "");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !anonKey) return json({ error: "Server isn't configured" }, 500);

  // Act as the signed-in person, so they can only ever delete themselves.
  const supabase = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

  console.log("step 1: checking who is signed in");
  const { data: userData, error: userError } = await supabase.auth.getUser(accessToken);
  if (userError || !userData?.user) {
    console.error("not signed in:", userError?.message);
    return json({ error: "Not signed in" }, 401);
  }

  // 1. Revoke Sign in with Apple (best effort).
  let revoked = false;
  let revokeError: string | null = null;
  console.log("step 2: reading request");
  const body = await req.json().catch(() => ({}));
  const code = typeof body?.authorizationCode === "string" ? body.authorizationCode : "";
  if (code) {
    try {
      console.log("step 3: revoking with Apple");
      await revokeAppleAccess(code);
      console.log("step 3: Apple revoke done");
      revoked = true;
    } catch (e) {
      revokeError = e instanceof Error ? e.message : String(e);
      console.error("Apple revoke failed:", revokeError);
    }
  } else {
    revokeError = "No authorization code sent";
  }

  // 2. Delete the account (cascades to profile, messages, memberships…).
  console.log("step 4: deleting account");
  const { error: deleteError } = await supabase.rpc("delete_my_account");
  if (deleteError) {
    console.error("delete_my_account failed:", deleteError.message);
    return json({ error: "Couldn't delete the account", revoked }, 500);
  }

  console.log("step 5: done", JSON.stringify({ revoked, revokeError }));
  return json({ deleted: true, revoked, revokeError });
});

/** Short-lived JWT that proves to Apple the request comes from Quotidian. */
async function appleClientSecret(clientId: string): Promise<string> {
  const teamId = Deno.env.get("APPLE_TEAM_ID");
  const keyId = Deno.env.get("APPLE_KEY_ID");
  const pem = Deno.env.get("APPLE_PRIVATE_KEY")?.replace(/\\n/g, "\n");
  if (!teamId || !keyId || !pem) throw new Error("Apple key secrets are missing");

  const key = await importPKCS8(pem, "ES256");
  return await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: keyId })
    .setIssuer(teamId)
    .setIssuedAt()
    .setExpirationTime("5m")
    .setAudience("https://appleid.apple.com")
    .setSubject(clientId)
    .sign(key);
}

/** Exchange the one-time code for a token, then revoke it. */
async function revokeAppleAccess(authorizationCode: string): Promise<void> {
  const clientId = Deno.env.get("APPLE_CLIENT_ID");
  if (!clientId) throw new Error("APPLE_CLIENT_ID is missing");
  const clientSecret = await appleClientSecret(clientId);
  const form = { "Content-Type": "application/x-www-form-urlencoded" };

  const tokenResponse = await fetch("https://appleid.apple.com/auth/token", {
    method: "POST",
    headers: form,
    signal: AbortSignal.timeout(10_000),
    body: new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      code: authorizationCode,
      grant_type: "authorization_code",
    }),
  });
  const tokens = await tokenResponse.json().catch(() => ({}));
  if (!tokenResponse.ok) {
    throw new Error(`Token exchange failed: ${tokens?.error ?? tokenResponse.status}`);
  }

  const token = tokens.refresh_token ?? tokens.access_token;
  const hint = tokens.refresh_token ? "refresh_token" : "access_token";
  if (!token) throw new Error("Apple returned no token");

  const revokeResponse = await fetch("https://appleid.apple.com/auth/revoke", {
    method: "POST",
    headers: form,
    signal: AbortSignal.timeout(10_000),
    body: new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      token,
      token_type_hint: hint,
    }),
  });
  if (!revokeResponse.ok) throw new Error(`Revoke failed: ${revokeResponse.status}`);
}
