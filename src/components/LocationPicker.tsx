import React, { useEffect, useState } from "react";

export default function LocationPicker({ onChange }) {
  const [countries, setCountries] = useState([]);

  useEffect(() => {
    fetch("https://restcountries.com/v3.1/all")
      .then(res => res.json())
      .then(data =>
        setCountries(
          data.sort((a, b) =>
            a.name.common.localeCompare(b.name.common)
          )
        )
      );
  }, []);

  return (
    <>
      <select name="country_code" onChange={onChange} required>
        <option value="">Select Country</option>
        {countries.map(c => (
          <option key={c.cca2} value={c.cca2}>
            {c.name.common}
          </option>
        ))}
      </select>

      <input name="state" onChange={onChange} placeholder="State" />
      <input name="city" onChange={onChange} placeholder="City" required />
    </>
  );
}
