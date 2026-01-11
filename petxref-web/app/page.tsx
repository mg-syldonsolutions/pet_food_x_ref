import Link from "next/link";

export default function Home() {
  return (
    <main className="min-h-screen bg-zinc-50 dark:bg-black text-gray-900 dark:text-gray-50">
      <div className="flex flex-col items-center justify-center text-center px-6 py-32 space-y-8">
        <h1 className="text-5xl font-extrabold leading-tight">
          Compare Pet Food Ingredients
        </h1>

        <p className="max-w-xl text-lg text-gray-700 dark:text-gray-300">
          Quickly find common and unique ingredients across pet foods — and search for foods without specific ingredients.
        </p>

        <div className="flex flex-col sm:flex-row gap-4">
          <Link href="/products" className="px-6 py-3 bg-indigo-600 text-white font-semibold rounded shadow hover:bg-indigo-700 transition">
            Browse Products
          </Link>

          <Link href="/compare" className="px-6 py-3 border border-indigo-600 text-indigo-600 font-semibold rounded hover:bg-indigo-50 dark:hover:bg-indigo-900 transition">
            Compare Foods
          </Link>
        </div>
      </div>

      <section className="bg-white dark:bg-gray-900 py-12">
        <div className="max-w-3xl mx-auto text-center space-y-4 px-6">
          <h2 className="text-3xl font-semibold">How It Works</h2>
          <p className="text-gray-700 dark:text-gray-300">
            1. Browse the catalog of pet foods.
            <br />
            2. Select foods to compare ingredients.
            <br />
            3. Exclude ingredients and find alternatives.
          </p>
        </div>
      </section>
    </main>
  );
}

