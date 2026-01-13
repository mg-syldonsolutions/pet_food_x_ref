"use client";

import { useEffect, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import ProductCard from "@/components/ProductCard";
import IngredientMultiSelect, { Option } from "@/components/IngredientMultiSelect";

export default function ProductsPage() {
  const router = useRouter();
  const searchParams = useSearchParams();

  const species = searchParams?.get("species") || "";
  const format = searchParams?.get("format") || "";
  const lifeStage = searchParams?.get("life_stage") || "";
  const pageParam = searchParams?.get("page") || "1";
  const page = parseInt(pageParam, 10) || 1;

  const excludeValues = searchParams?.getAll("exclude") || [];
  const initialExclusions = excludeValues.map((v) => ({
    value: v,
    label: v,
  }));

  const currentSort = searchParams?.get("sort") || "";

  const [products, setProducts] = useState<any[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [totalCount, setTotalCount] = useState(0);
  const [excludeTerms, setExcludeTerms] = useState<Option[]>(initialExclusions);

  const pageSize = 20;

  const ingredientOptions: Option[] = [
    { value: "peas", label: "Peas" },
    { value: "soy", label: "Soy" },
    { value: "corn", label: "Corn" },
    { value: "rice", label: "Rice" },
  ];

  const sortOptions: Option[] = [
    { value: "", label: "Default" },
    { value: "name_asc", label: "Name A→Z" },
    { value: "name_desc", label: "Name Z→A" },
    { value: "brand_asc", label: "Brand A→Z" },
    { value: "brand_desc", label: "Brand Z→A" },
  ];

  const fetchProducts = async () => {
    setIsLoading(true);

    const body: any = {
      species: species || null,
      format: format || null,
      life_stage: lifeStage || null,
      limit: pageSize,
      offset: (page - 1) * pageSize,
      exclude_terms: excludeTerms.map((t) => t.value),
      sort: currentSort || null,
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
  }, [
    species,
    format,
    lifeStage,
    page,
    excludeTerms,
    currentSort,
  ]);

  const updateUrlParams = (
    updates: [string, string | string[]][]
  ) => {
    const params = new URLSearchParams(searchParams?.toString() || "");

    updates.forEach(([key, val]) => {
      if (Array.isArray(val)) {
        params.delete(key);
        val.forEach((v) => params.append(key, v));
      } else if (val) {
        params.set(key, val);
      } else {
        params.delete(key);
      }
    });

    params.delete("page");
    router.push(`/products?${params.toString()}`);
  };

  const totalPages = Math.ceil(totalCount / pageSize);

  return (
    <main className="max-w-5xl mx-auto p-6 space-y-6">
      <h1 className="text-3xl font-bold">Product Catalog</h1>

      {/* Filters */}
      <div className="flex flex-wrap gap-4 items-center">
        <select
          value={species}
          onChange={(e) =>
            updateUrlParams([["species", e.target.value]])
          }
          className="border px-3 py-2 rounded"
        >
          <option value="">All Species</option>
          <option value="dog">Dog</option>
          <option value="cat">Cat</option>
        </select>

        <select
          value={format}
          onChange={(e) =>
            updateUrlParams([["format", e.target.value]])
          }
          className="border px-3 py-2 rounded"
        >
          <option value="">All Formats</option>
          <option value="dry">Dry</option>
          <option value="wet">Wet</option>
        </select>

        <select
          value={lifeStage}
          onChange={(e) =>
            updateUrlParams([["life_stage", e.target.value]])
          }
          className="border px-3 py-2 rounded"
        >
          <option value="">All Life Stages</option>
          <option value="adult">Adult</option>
          <option value="puppy">Puppy</option>
          <option value="kitten">Kitten</option>
        </select>

        <select
          value={currentSort}
          onChange={(e) =>
            updateUrlParams([["sort", e.target.value]])
          }
          className="border px-3 py-2 rounded"
        >
          {sortOptions.map((opt) => (
            <option key={opt.value} value={opt.value}>
              {opt.label}
            </option>
          ))}
        </select>

        <button
          onClick={() => router.push("/products")}
          className="px-3 py-2 bg-gray-200 rounded hover:bg-gray-300"
        >
          Clear All
        </button>
      </div>

      {/* ** Styled Ingredient Multi-Select ** */}
      <div className="flex gap-4 items-center">
        <div className="min-w-[280px]">
          <IngredientMultiSelect
            value={excludeTerms}
            options={ingredientOptions}
            onChange={(arr) => {
              setExcludeTerms(arr);
              updateUrlParams([["exclude", arr.map((o) => o.value)]]);
            }}
          />
        </div>
      </div>

      {/* Products + Pagination */}
      {isLoading ? (
        <p className="text-gray-700">Loading…</p>
      ) : (
        <>
          <div className="grid gap-4 grid-cols-1 sm:grid-cols-2 lg:grid-cols-3">
            {products.map((p) => (
              <ProductCard key={p.id} product={p} />
            ))}
          </div>

          <div className="flex justify-between items-center pt-6">
            <button
              onClick={() =>
                updateUrlParams([["page", String(page - 1)]])
              }
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
                updateUrlParams([["page", String(page + 1)]])
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
