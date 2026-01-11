"use client";

import { useEffect, useState } from "react";
import Button from "./Button";

type Props = {
  productSlug: string;
  productName: string;
};

const STORAGE_KEY = "petxref_compare_list";

export default function AddToCompare({ productSlug, productName }: Props) {
  const [compareList, setCompareList] = useState<string[]>([]);
  const [isAdded, setIsAdded] = useState(false);

  useEffect(() => {
    // load from localStorage
    try {
      const stored = localStorage.getItem(STORAGE_KEY);
      if (stored) {
        const arr = JSON.parse(stored);
        setCompareList(arr);
        setIsAdded(arr.includes(productSlug));
      }
    } catch (e) {
      console.warn("compare list load failed", e);
    }
  }, [productSlug]);

  const saveList = (list: string[]) => {
    setCompareList(list);
    localStorage.setItem(STORAGE_KEY, JSON.stringify(list));
  };

  const onAdd = () => {
    const next = [...compareList, productSlug];
    saveList(next);
    setIsAdded(true);
  };

  const onRemove = () => {
    const next = compareList.filter((s) => s !== productSlug);
    saveList(next);
    setIsAdded(false);
  };

  return (
    <div className="space-x-2">
      {isAdded ? (
        <Button onClick={onRemove} className="bg-red-500 hover:bg-red-600">
          Remove from Compare
        </Button>
      ) : (
        <Button onClick={onAdd} className="bg-green-600 hover:bg-green-700">
          Add to Compare
        </Button>
      )}
      {compareList.length > 1 && (
        <Button
          onClick={() => {
            // redirect to compare page with tokens
            const tokens = compareList.map((t) => `product_tokens=${t}`).join("&");
            window.location.href = `/compare?${tokens}`;
          }}
          className="bg-indigo-600 hover:bg-indigo-700"
        >
          Compare {compareList.length} Items
        </Button>
      )}
    </div>
  );
}
