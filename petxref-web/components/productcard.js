import Link from "next/link";

export default function ProductCard({ product }) {
  return (
    <Link href={`/products/${product.slug}`}>
      <a className="card">
        <h3>{product.name}</h3>
        <p>{product.brand.name}</p>
      </a>
    </Link>
  );
}
