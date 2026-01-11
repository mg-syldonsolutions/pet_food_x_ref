import Link from "next/link";

export default function SiteHeader() {
  return (
    <header className="bg-white dark:bg-gray-900 shadow-sm">
      <nav className="max-w-4xl mx-auto px-6 py-4 flex items-center justify-between">
        <Link href="/" className="text-xl font-bold text-indigo-600 dark:text-indigo-400">
          PetXref
        </Link>

        <div className="space-x-4 text-gray-700 dark:text-gray-300">
          <Link href="/products" className="hover:text-indigo-600 dark:hover:text-indigo-400">
            Products
          </Link>
          <Link href="/compare" className="hover:text-indigo-600 dark:hover:text-indigo-400">
            Compare
          </Link>
          <Link href="/search" className="hover:text-indigo-600 dark:hover:text-indigo-400">
            Search
          </Link>
        </div>
      </nav>
    </header>
  );
}
