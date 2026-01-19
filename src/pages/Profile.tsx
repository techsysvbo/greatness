import React, { useState } from "react";
import LocationPicker from "../components/LocationPicker";

export default function Profile() {
  const [form, setForm] = useState({});

  function handleChange(e) {
    setForm({ ...form, [e.target.name]: e.target.value });
  }

  async function handleSubmit(e) {
    e.preventDefault();

    const res = await fetch("/api/profile/me", {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(form),
    });

    const data = await res.json();

    if (!res.ok) {
      alert(data.error || "Failed to update profile");
      return;
    }

    alert("Profile updated 🎉");
  }

  return (
    <form onSubmit={handleSubmit}>
      <input name="display_name" onChange={handleChange} placeholder="Name" />
      <input name="profession" onChange={handleChange} placeholder="Profession" />
      <LocationPicker onChange={handleChange} />
      <textarea name="bio" onChange={handleChange} placeholder="Bio" />
      <button type="submit">Save</button>
    </form>
  );
}
