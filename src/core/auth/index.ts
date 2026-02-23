import { redirect } from "next/navigation";
import { createClient } from "@/core/db/server";

export async function protectRoute(allowedRoles: string[]): Promise<string> {
  const supabase = await createClient();
  const {
    data: { user },
    error: userError,
  } = await supabase.auth.getUser();

  if (userError || !user) {
    redirect("/login");
  }

  const { data: profile, error: profileError } = await supabase
    .from("profiles")
    .select("roles(name)")
    .eq("id", user.id)
    .single();

  if (profileError || !profile) {
    redirect("/login");
  }

  const roles = (profile as unknown as { roles: { name: string } | null }).roles;
  const roleName = roles?.name ?? null;
  if (!roleName || !allowedRoles.includes(roleName)) {
    redirect("/login");
  }

  return roleName;
}
