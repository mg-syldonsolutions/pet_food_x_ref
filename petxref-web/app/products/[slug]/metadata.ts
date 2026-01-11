export async function generateMetadata({ params }: { params: { slug: string } }) {
  const res = await fetch(`${process.env.NEXT_PUBLIC_API_BASE}/catalog/products/${params.slug}`);
  if (!res.ok) return { title: "Product Not Found" };

  const product = await res.json();

  return {
    title: `${product.name} | PetXref`,
    description: `Details and ingredients for ${product.name}`,
  };
}
