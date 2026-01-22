#!/usr/bin/env bash
set -euo pipefail
cd /mnt/c/Users/techs/OneDrive/Desktop/ag-workspace

echo "==> Overwriting profile auth middleware to accept JWT payload { userId }"
cat > services/profile/src/middleware/authMiddleware.ts <<'TS'
import { Request, Response, NextFunction } from "express";
import jwt from "jsonwebtoken";

export interface AuthRequest extends Request {
  user?: { id: number; email?: string };
}

function getBearerToken(auth?: string) {
  if (!auth) return "";
  if (auth.startsWith("Bearer ")) return auth.slice(7).trim();
  return "";
}

export const authMiddleware = (req: AuthRequest, res: Response, next: NextFunction) => {
  const token =
    getBearerToken(req.headers.authorization) ||
    (typeof req.headers["x-access-token"] === "string" ? req.headers["x-access-token"] : "");

  if (!token) {
    return res.status(401).json({ message: "Unauthorized: missing token" });
  }

  try {
    const decoded: any = jwt.verify(token, process.env.JWT_SECRET || "dev_secret_key_change_me");

    // ✅ accept both userId and id
    const uid = decoded.userId ?? decoded.id;
    if (!uid) {
      return res.status(401).json({ message: "Unauthorized: token missing userId/id" });
    }

    req.user = { id: Number(uid), email: decoded.email };
    return next();
  } catch (e: any) {
    return res.status(401).json({ message: "Unauthorized: invalid token", detail: e?.message });
  }
};
TS

echo "==> Rebuild + restart profile-service"
docker-compose build --no-cache profile-service
docker-compose up -d profile-service

echo "==> Done"
