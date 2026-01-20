import { Request, Response, NextFunction } from "express";
import jwt from "jsonwebtoken";

export interface AuthRequest extends Request {
  user?: { id: number; email?: string; username?: string };
}

function parseCookies(cookieHeader?: string): Record<string, string> {
  const out: Record<string, string> = {};
  if (!cookieHeader) return out;

  cookieHeader.split(";").forEach((part) => {
    const [k, ...rest] = part.trim().split("=");
    if (!k) return;
    out[k] = decodeURIComponent(rest.join("=") || "");
  });

  return out;
}

export const authMiddleware = (req: AuthRequest, res: Response, next: NextFunction) => {
  // 1) Authorization: Bearer <token>
  const auth = req.headers.authorization;
  let token: string | undefined;

  if (auth && auth.startsWith("Bearer ")) {
    token = auth.slice("Bearer ".length).trim();
  }

  // 2) x-access-token header
  if (!token) {
    const x = req.headers["x-access-token"];
    if (typeof x === "string" && x.length > 0) token = x;
  }

  // 3) Cookie token (supports multiple common names)
  if (!token) {
    const cookies = parseCookies(req.headers.cookie);
    token =
      cookies["token"] ||
      cookies["accessToken"] ||
      cookies["authToken"] ||
      cookies["jwt"] ||
      cookies["Authorization"];
  }

  if (!token) {
    return res.status(401).json({ message: "Unauthorized: missing token" });
  }

  try {
    const decoded: any = jwt.verify(token, process.env.JWT_SECRET || "dev_secret_key_change_me");

    // Support either { id } or { userId }
    const id = decoded.id ?? decoded.userId;
    if (!id) {
      return res.status(401).json({ message: "Unauthorized: token missing id/userId" });
    }

    req.user = { id: Number(id), email: decoded.email, username: decoded.username };
    return next();
  } catch (err: any) {
    return res.status(401).json({ message: "Unauthorized: invalid token", detail: err?.message });
  }
};
