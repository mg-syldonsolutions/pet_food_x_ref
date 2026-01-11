"use client";

import { useSearchParams } from "next/navigation";
import { useEffect, useState } from "react";

export default function ComparePage() {
  const searchParams = useSearchParams();
  const [tokens, setTokens] = useState<string[]>([]);
  const [results, setResults] = useState(null);

  useEffect(() => {
    const arr: string[] = [];
    if (!searchParams) {
      setTokens([]);
      return;
    }
    for (const value of searchParams.getAll("product_tokens")) {
      arr.push(value);
    }
    setTokens(arr);
  }, [searchParams]);

  const doCompare = async () => {
    const res = await fetch(
      `${process.env.NEXT_PUBLIC_API_BASE}/compare`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ product_tokens: tokens, mode: "canonical" }),
      }
    );
    setResults(await res.json());
  };

  return (
    <main className="max-w-4xl mx-auto p-6 space-y-6">
      {/* same JSX as above */}
    </main>
  );
}
