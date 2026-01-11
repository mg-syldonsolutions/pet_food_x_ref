import Head from "next/head";
import { apiGet } from "../../lib/api";
import Link from "next/link";

export default function ProductsPage({ products }) {
  return (
    <>
      <Head>
        <title>All Pet Foods | PetXref</title>
        <meta name="description" content="Browse all pet foods and their ingredients." />
      </Head>

      <main>
        <h1>Pet Food Catalog</h1>
        <div className="grid">
          {products.map((p) => (
            <Link key={p.id} href={`/products/${p.slug}`}>
              <a className="card">
                <h2>{p.name}</h2>
                <p>{p.brand.name}</p>
              </a>
            </Link>
          ))}
        </div>
      </main>
    </>
  );
}

export async function getStaticProps() {
  const data = await apiGet("/catalog/products");
  return {
    props: { products: data.items },
    revalidate: 60,
  };
}
