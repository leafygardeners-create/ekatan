import { NextResponse, type NextRequest } from "next/server";
import { updateSession } from "@/core/db/middleware";

const PROTECTED_PREFIXES = [
  "/admin",
  "/designer",
  "/supervisor",
  "/analytics",
  "/cart",
  "/quote",
];

function isProtectedPath(pathname: string): boolean {
  return PROTECTED_PREFIXES.some((prefix) => pathname.startsWith(prefix));
}

export async function middleware(request: NextRequest) {
  const { response, user } = await updateSession(request);

  if (!isProtectedPath(request.nextUrl.pathname)) {
    return response;
  }

  if (!user) {
    const redirectResponse = NextResponse.redirect(new URL("/login", request.url));
    response.cookies.getAll().forEach((cookie) => {
      redirectResponse.cookies.set(cookie.name, cookie.value);
    });
    return redirectResponse;
  }

  return response;
}

export const config = {
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)",
  ],
};
