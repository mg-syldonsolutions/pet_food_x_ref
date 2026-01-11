"use client";

import { useEffect, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import ProductCard from "@/components/ProductCard";

export default function ProductsPage() {
  const router = useRouter();
  const searchParams = useSearchParams();

  // Read search params (filters + pagination)
  const species = searchParams?.get("species") || "";
  const format = searchParams?.get("format") || "";
  const lifeStage = searchParams?.get("life_stage") || "";
  const pageParam = searchParams?.get("page") || "1";
  const page = parseInt(pageParam, 10) || 1;

  const [products, setProducts] = useState<any[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [totalCount, setTotalCount] = useState(0);

  const pageSize = 20;

  const fetchProducts = async () => {
    setIsLoading(true);

    const body: any = {
      species: species || null,
      format: format || null,
      life_stage: lifeStage || null,
      limit: pageSize,
      offset: (page - 1) * pageSize,
    };

    const res = await fetch(
      `${process.env.NEXT_PUBLIC_API_BASE}/catalog/search`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      }
    );

    const data = await res.json();

    setProducts(data.items || []);
    setTotalCount(data.total_count || 0);
    setIsLoading(false);
  };

  useEffect(() => {
    fetchProducts();
  }, [species, format, lifeStage, page]);

  // Helper to update search params
  const updateQuery = (key: string, value: string) => {
    const params = new URLSearchParams(searchParams?.toString() || "");

    if (value) {
      params.set(key, value);
    } else {
      params.delete(key);
    }

    // Reset to page 1 if filters change
    params.delete("page");

    const queryString = params.toString();
    router.push(`/products${queryString ? `?${queryString}` : ""}`);
  };

  const totalPages = Math.ceil(totalCount / pageSize);

  return (
    <main className="max-w-5xl mx-auto p-6 space-y-6">
      <h1 className="text-3xl font-bold">Product Catalog</h1>

      {/* Filters */}
      <div className="flex flex-wrap gap-4 items-center">
        <select
          value={species}
          onChange={(e) => updateQuery("species", e.target.value)}
          className="border px-3 py-2 rounded"
        >
          <option value="">All Species</option>
          <option value="dog">Dog</option>
          <option value="cat">Cat</option>
        </select>

        <select
          value={format}
          onChange={(e) => updateQuery("format", e.target.value)}
          className="border px-3 py-2 rounded"
        >
          <option value="">All Formats</option>
          <option value="dry">Dry</option>
          <option value="wet">Wet</option>
        </select>

        <select
          value={lifeStage}
          onChange={(e) => updateQuery("life_stage", e.target.value)}
          className="border px-3 py-2 rounded"
        >
          <option value="">All Life Stages</option>
          <option value="adult">Adult</option>
          <option value="puppy">Puppy</option>
          <option value="kitten">Kitten</option>
        </select>

        <button
          onClick={() => router.push("/products")}
          className="px-3 py-2 bg-gray-200 rounded hover:bg-gray-300"
        >
          Clear Filters
        </button>
      </div>

      {/* Product Grid + Pagination */}
      {isLoading ? (
        <p className="text-gray-700">Loading products…</p>
      ) : (
        <>
          <div className="grid gap-4 grid-cols-1 sm:grid-cols-2 lg:grid-cols-3">
            {products.map((p) => (
              <ProductCard key={p.id} product={p} />
            ))}
          </div>

          <div className="flex justify-between items-center pt-6">
            <button
              onClick={() => updateQuery("page", String(Math.max(page - 1, 1)))}
              disabled={page <= 1}
              className="px-4 py-2 bg-gray-200 rounded hover:bg-gray-300 disabled:opacity-50"
            >
              Previous
            </button>

            <span>
              Page {page} of {totalPages}
            </span>

            <button
              onClick={() =>
                updateQuery(
                  "page",
                  String(Math.min(page + 1, totalPages))
                )
              }
              disabled={page >= totalPages}
              className="px-4 py-2 bg-gray-200 rounded hover:bg-gray-300 disabled:opacity-50"
            >
              Next
            </button>
          </div>
        </>
      )}
    </main>
  );
}
