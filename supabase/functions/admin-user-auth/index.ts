import { createClient } from "jsr:@supabase/supabase-js@2";

type RequestBody = {
  action?: "list" | "verify" | "resend" | "create";
  userIds?: string[];
  userId?: string;
  accessToken?: string;
  email?: string;
  password?: string;
  fullName?: string;
  autoVerify?: boolean;
  sendVerificationEmail?: boolean;
};

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

async function ensureAdmin(jwt: string) {
  const adminClient = createClient(supabaseUrl, serviceRoleKey);
  const {
    data: { user },
    error: userError,
  } = await adminClient.auth.getUser(jwt);

  if (userError != null || user == null) {
    throw new Error("Unauthorized");
  }

  const { data: adminProfile, error: adminError } = await adminClient
    .from("profiles")
    .select("is_admin")
    .eq("id", user.id)
    .maybeSingle();

  if (adminError != null || adminProfile?.is_admin !== true) {
    throw new Error("Admin access required");
  }

  return { adminClient, adminUserId: user.id };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return Response.json(
      { error: "Method not allowed" },
      { status: 405, headers: corsHeaders },
    );
  }

  const authHeader = req.headers.get("Authorization");
  const body = (await req.json()) as RequestBody;
  const headerToken = authHeader?.replace(/^Bearer\s+/i, "").trim() ?? "";
  const bodyToken = body.accessToken?.trim() ?? "";
  const jwt = headerToken.length > 0 ? headerToken : bodyToken;
  if (jwt.length === 0) {
    return Response.json(
      { error: "Missing access token" },
      { status: 401, headers: corsHeaders },
    );
  }

  try {
    const { adminClient, adminUserId } = await ensureAdmin(jwt);
    const action = body.action ?? "list";

    if (action === "list") {
      const requestedIds = (body.userIds ?? [])
        .map((id) => id.trim())
        .filter((id) => id.length > 0);

      if (requestedIds.length > 0) {
        const settled = await Promise.all(
          requestedIds.map(async (id) => {
            const { data, error } = await adminClient.auth.admin.getUserById(id);
        if (error != null || data.user == null) {
          return {
            id,
            email: "",
            verified: null,
                email_confirmed_at: null,
                confirmed_at: null,
              };
            }

            const user = data.user;
            return {
              id: user.id,
              email: user.email ?? "",
              verified: Boolean(user.email_confirmed_at ?? user.confirmed_at),
              email_confirmed_at: user.email_confirmed_at,
              confirmed_at: user.confirmed_at,
            };
          }),
        );

        return Response.json({ users: settled }, { headers: corsHeaders });
      }

      const allUsers: Awaited<
        ReturnType<typeof adminClient.auth.admin.listUsers>
      >["data"]["users"] = [];
      let page = 1;
      const perPage = 100;

      while (true) {
        const { data, error } = await adminClient.auth.admin.listUsers({
          page,
          perPage,
        });
        if (error != null) {
          return Response.json(
            { error: error.message },
            { status: 500, headers: corsHeaders },
          );
        }

        const batch = data.users ?? [];
        allUsers.push(...batch);
        if (batch.length < perPage) break;
        page += 1;
      }

      const users = allUsers
        .map((user) => ({
          id: user.id,
          email: user.email ?? "",
          verified: Boolean(user.email_confirmed_at ?? user.confirmed_at),
          email_confirmed_at: user.email_confirmed_at,
          confirmed_at: user.confirmed_at,
        }));

      return Response.json({ users }, { headers: corsHeaders });
    }

    if (action === "create") {
      const email = body.email?.trim().toLowerCase() ?? "";
      const password = body.password ?? "";
      const fullName = body.fullName?.trim() ?? "";
      const autoVerify = body.autoVerify === true;
      const sendVerificationEmail = body.sendVerificationEmail === true;

      if (!email) {
        return Response.json(
          { error: "Email is required" },
          { status: 400, headers: corsHeaders },
        );
      }

      if (password.length < 6) {
        return Response.json(
          { error: "Password must be at least 6 characters" },
          { status: 400, headers: corsHeaders },
        );
      }

      const { data: created, error: createError } =
        await adminClient.auth.admin.createUser({
          email,
          password,
          email_confirm: autoVerify,
        });

      if (createError != null || created.user == null) {
        return Response.json(
          { error: createError?.message ?? "Failed to create user" },
          { status: 500, headers: corsHeaders },
        );
      }

      const user = created.user;
      const profilePayload: Record<string, unknown> = {
        id: user.id,
      };
      if (fullName.length > 0) {
        profilePayload.full_name = fullName;
      }

      const { error: profileError } = await adminClient
        .from("profiles")
        .upsert(profilePayload, { onConflict: "id" });

      if (profileError != null) {
        await adminClient.auth.admin.deleteUser(user.id);
        return Response.json(
          { error: profileError.message },
          { status: 500, headers: corsHeaders },
        );
      }

      if (!autoVerify && sendVerificationEmail) {
        const anonClient = createClient(supabaseUrl, anonKey);
        const { error: resendError } = await anonClient.auth.resend({
          type: "signup",
          email,
        });
        if (resendError != null) {
          return Response.json(
            {
              user: {
                id: user.id,
                email: user.email ?? email,
                verified: false,
              },
              warning: resendError.message,
            },
            { headers: corsHeaders },
          );
        }
      }

      return Response.json(
        {
          user: {
            id: user.id,
            email: user.email ?? email,
            verified: Boolean(user.email_confirmed_at ?? user.confirmed_at ?? autoVerify),
          },
        },
        { headers: corsHeaders },
      );
    }

    const userId = body.userId?.trim();
    if (!userId) {
      return Response.json(
        { error: "userId is required" },
        { status: 400, headers: corsHeaders },
      );
    }

    if (userId === adminUserId) {
      return Response.json(
        { error: "You cannot modify your own admin account" },
        { status: 400, headers: corsHeaders },
      );
    }

    const { data: fetched, error: fetchError } = await adminClient.auth.admin.getUserById(userId);
    if (fetchError != null || fetched.user == null) {
      return Response.json(
        { error: "User not found" },
        { status: 404, headers: corsHeaders },
      );
    }

    if (action === "verify") {
      const { error } = await adminClient.auth.admin.updateUserById(userId, {
        email_confirm: true,
      });
      if (error != null) {
        return Response.json(
          { error: error.message },
          { status: 500, headers: corsHeaders },
        );
      }
      return Response.json({ ok: true }, { headers: corsHeaders });
    }

    if (action === "resend") {
      const email = fetched.user.email?.trim();
      if (!email) {
        return Response.json(
          { error: "User email not found" },
          { status: 400, headers: corsHeaders },
        );
      }

      const anonClient = createClient(supabaseUrl, anonKey);
      const { error } = await anonClient.auth.resend({
        type: "signup",
        email,
      });
      if (error != null) {
        return Response.json(
          { error: error.message },
          { status: 500, headers: corsHeaders },
        );
      }
      return Response.json({ ok: true }, { headers: corsHeaders });
    }

    return Response.json(
      { error: "Unsupported action" },
      { status: 400, headers: corsHeaders },
    );
  } catch (error) {
    return Response.json(
      { error: error instanceof Error ? error.message : String(error) },
      { status: 403, headers: corsHeaders },
    );
  }
});
