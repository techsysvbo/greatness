export async function updateProfile(req: any, res: Response) {
  try {
    const userId = req.user.id;

    const {
      display_name,
      profession,
      country_code,
      state,
      city,
      bio,
      interests,
    } = req.body;

    if (!country_code || !city) {
      return res.status(400).json({
        error: "Country and city are required",
      });
    }

    // Ensure interests is a TEXT[] (Postgres array)
    const interestsArray =
      typeof interests === "string"
        ? interests.split(",").map((i: string) => i.trim())
        : interests;

    const result = await pool.query(
      `
      INSERT INTO profiles (
        user_id,
        display_name,
        profession,
        country_code,
        state,
        city,
        bio,
        interests,
        updated_at
      )
      VALUES ($1,$2,$3,$4,$5,$6,$7,$8,NOW())
      ON CONFLICT (user_id) DO UPDATE SET
        display_name = EXCLUDED.display_name,
        profession = EXCLUDED.profession,
        country_code = EXCLUDED.country_code,
        state = EXCLUDED.state,
        city = EXCLUDED.city,
        bio = EXCLUDED.bio,
        interests = EXCLUDED.interests,
        updated_at = NOW()
      RETURNING *
      `,
      [
        userId,
        display_name,
        profession,
        country_code,
        state,
        city,
        bio,
        interestsArray,
      ]
    );

    return res.json(result.rows[0]);
  } catch (err: any) {
    console.error("UPDATE PROFILE ERROR:", err);

    return res.status(500).json({
      error: "Failed to update profile",
      detail: err.message,
      code: err.code,
      constraint: err.constraint,
    });
  }
}
