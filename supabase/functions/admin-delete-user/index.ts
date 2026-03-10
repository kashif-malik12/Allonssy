import { createClient } from "jsr:@supabase/supabase-js@2";

type DeleteUserRequest = {
  userId?: string;
  accessToken?: string;
};

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

async function removeBucketPrefix(
  adminClient: ReturnType<typeof createClient>,
  bucket: string,
  prefix: string,
) {
  const normalizedPrefix = prefix.endsWith("/") ? prefix.slice(0, -1) : prefix;
  const { data, error } = await adminClient.storage
    .from(bucket)
    .list(normalizedPrefix, {
      limit: 1000,
      offset: 0,
    });

  if (error != null) {
    throw new Error(error.message);
  }

  const paths = (data ?? [])
    .map((row: { name?: string }) => row.name ?? "")
    .filter((name: string) => name.length > 0)
    .map((name: string) => `${normalizedPrefix}/${name}`);

  if (paths.length === 0) return;

  const { error: removeError } = await adminClient.storage.from(bucket).remove(paths);
  if (removeError != null) {
    throw new Error(removeError.message);
  }
}

Deno.serve(async (req) => {
  if (req.method != "POST") {
    return Response.json({ error: "Method not allowed" }, { status: 405 });
  }

  const authHeader = req.headers.get("Authorization");
  const body = await req.json() as DeleteUserRequest;
  const headerToken = authHeader?.replace(/^Bearer\s+/i, "").trim() ?? "";
  const jwt = headerToken.isNotEmpty ? headerToken : (body.accessToken?.trim() ?? "");
  if (jwt.length === 0) {
    return Response.json({ error: "Missing access token" }, { status: 401 });
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey);
  const userClient = createClient(supabaseUrl, anonKey, {
    global: {
      headers: {
        Authorization: `Bearer ${jwt}`,
      },
    },
  });
  const {
    data: { user },
    error: userError,
  } = await adminClient.auth.getUser(jwt);

  if (userError != null || user == null) {
    return Response.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { data: adminProfile, error: adminError } = await adminClient
    .from("profiles")
    .select("is_admin")
    .eq("id", user.id)
    .maybeSingle();

  if (adminError != null || adminProfile?.is_admin !== true) {
    return Response.json({ error: "Admin access required" }, { status: 403 });
  }

  const userId = body.userId?.trim();
  if (userId == null || userId.isEmpty) {
    return Response.json({ error: "userId is required" }, { status: 400 });
  }

  if (userId == user.id) {
    return Response.json({ error: "You cannot delete your own account" }, { status: 400 });
  }

  const { error: purgeError } = await userClient.rpc(
    "admin_delete_user_account_data_only",
    { p_user_id: userId },
  );

  if (purgeError != null) {
    return Response.json({ error: purgeError.message }, { status: 400 });
  }

  try {
    await removeBucketPrefix(adminClient, "avatars", `${userId}/`);
    await removeBucketPrefix(adminClient, "portfolio-images", `portfolio/${userId}/`);
    await removeBucketPrefix(adminClient, "post-images", `${userId}/`);
  } catch (storageError) {
    return Response.json({
      error: "App data was removed, but storage cleanup failed",
      details: storageError instanceof Error ? storageError.message : String(storageError),
    }, { status: 500 });
  }

  const { error: deleteError } = await adminClient.auth.admin.deleteUser(
    userId,
    false,
  );

  if (deleteError != null) {
    return Response.json({
      error: "App data was removed, but Auth user deletion failed",
      details: deleteError.message,
    }, { status: 500 });
  }

  return Response.json({ ok: true });
});
