import Head from "next/head";

export default function Home() {
  return (
    <>
      <Head>
        <title>PetXref – Compare Pet Food Ingredients</title>
        <meta
          name="description"
          content="Compare common and unique ingredients across pet foods and find options without specific ingredients."
        />
      </Head>

      <main>
        <h1>Welcome to PetXref</h1>
        <p>
          Compare pet foods and search ingredients with ease.
        </p>
      </main>
    </>
  );
}
