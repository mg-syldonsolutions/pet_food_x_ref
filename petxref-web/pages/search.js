import Head from "next/head";
import { useState } from "react";
import { apiPost } from "../lib/api";

export default function SearchPage() {
  const [species, setSpecies] = useState("");
  const [format, setFormat] = useState("");
  const [lifeStage, setLifeStage] = useState("");
  const [excludeIds, setExcludeIds] = useState("");
  const [results, setResults] = useState(null);

  const doSearch = async () => {
    const arr = excludeIds.split(",").map((id) => id.trim());
    const res = await apiPost("/catalog/search", {
      species, format_, life_stage: lifeStage, exclude_canonical_ids: arr,
    });
    setResults(res);
  };

  return (
    <>
      <Head>
        <title>Search Without Ingredients | PetXref</title>
        <meta
          name="description"
          content="Find pet foods that exclude specific ingredients."
        />
      </Head>

      <main>
        <h1>Search Excluding Ingredients</h1>
        {/* form inputs same as earlier */}
      </main>
    </>
  );
}
