// petxref-web/components/IngredientMultiSelect.tsx
"use client";

import Select from "react-select";
import { Filter } from "lucide-react";

export type Option = {
  value: string;
  label: string;
};

export default function IngredientMultiSelect({
  value,
  options,
  onChange,
}: {
  value: Option[];
  options: Option[];
  onChange: (next: Option[]) => void;
}) {
  return (
    <Select
      isMulti
      value={value}
      onChange={(opts) => onChange(opts as Option[])}
      options={options}
      placeholder={
        <div className="flex items-center gap-2 text-gray-600">
          <Filter className="w-4 h-4" />
          Exclude ingredients
        </div>
      }
      classNames={{
        control: () =>
          "border border-gray-300 rounded-md bg-white focus-within:ring-2 focus-within:ring-indigo-500",
        input: () => "text-sm",
        placeholder: () => "text-gray-500 text-sm flex items-center gap-2",
        multiValue: () =>
          "bg-indigo-100 text-indigo-900 px-2 py-1 rounded flex items-center",
        multiValueLabel: () => "pr-1 text-sm",
        multiValueRemove: () =>
          "text-indigo-600 hover:text-indigo-800 cursor-pointer",
        menu: () =>
          "border border-gray-300 rounded-md bg-white shadow-lg text-sm",
        option: () =>
          "cursor-pointer px-3 py-2 hover:bg-indigo-50 text-sm",
      }}
    />
  );
}
