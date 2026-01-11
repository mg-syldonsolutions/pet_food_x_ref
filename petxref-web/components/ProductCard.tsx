import Link from "next/link";

export type ProductSummary = {
  id: string;
  slug: string;
  name: string;
  species: string;
  format: string;
  life_stage: string;
  brand: { id: string; name: string; slug: string };
};

export default function ProductCard({ product }: { product: ProductSummary }) {
  return (
    <Link
      href={`/products/${product.slug}`}
      className="block border rounded-lg p-4 hover:shadow-lg transition bg-white dark:bg-gray-800"
    >
      <h3 className="text-lg font-semibold text-indigo-700 dark:text-indigo-300">
        {product.name}
      </h3>
      <p className="text-sm text-gray-600 dark:text-gray-400">
        {product.brand.name}
      </p>
      <p className="text-xs text-gray-500 dark:text-gray-500">
        {product.species} · {product.format} · {product.life_stage}
      </p>
    </Link>
  );
}
