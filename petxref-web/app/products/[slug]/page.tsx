
import { notFound } from "next/navigation";
import Image from "next/image";
import AddToCompare from "@/components/AddToCompare";

type Props = {
  params: { slug: string };
};

export default async function ProductDetail({ params }: Props) {
  const { slug } = params;

  const res = await fetch(
    `${process.env.NEXT_PUBLIC_API_BASE}/catalog/products/${slug}`,
    {
      next: { revalidate: 60 },
    }
  );

  if (!res.ok) {
    return notFound(); // Next.js shows 404 if product not found
  }

  const product = await res.json();

  return (
    <main className="max-w-4xl mx-auto p-6 space-y-6">
      <h1 className="text-3xl font-bold">{product.name}</h1>
      <p className="text-sm text-gray-600 dark:text-gray-400">
        Brand: {product.brand.name}
      </p>

      <section>
        <h2 className="text-xl font-semibold">Ingredients</h2>
        {product.ingredient_list?.items?.length ? (
          <ul className="list-disc pl-6 space-y-1">
            {product.ingredient_list.items.map((item: any) => (
              <li key={item.id}>
                {item.raw_text}
                {item.is_trace && " (trace)"}
                {item.is_may_contain && " (may contain)"}
              </li>
            ))}
          </ul>
        ) : (
          <p>No ingredients listed.</p>
        )}
      </section>
      <section className="pt-4">
      <AddToCompare
        productSlug={product.slug}
        productName={product.name}
      />
    </section>
    </main>
  );
}
