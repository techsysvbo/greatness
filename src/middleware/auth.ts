import { Request, Response, NextFunction } from "express";

export function requireAuth(req: any, res: Response, next: NextFunction) {
  if (!req.user || !req.user.id) {
    return res.status(401).json({ error: "Unauthorized" });
  }
  next();
}
