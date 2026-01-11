"use client";

import { useEffect, useState } from "react";
import Select from "react-select";

type Option = { value: string; label: string };

export default function IngredientExclusionSelect({
  selected,
  onChange,
  options,
}: {
  selected: Option[];
  onChange: (next: Option[]) => void;
  options: Option[];
}) {
  return (
    <Select
      isMulti
      value={selected}
      onChange={(opts) => onChange(opts as Option[])}
      options={options}
      placeholder="Exclude ingredients..."
      className="min-w-[250px] text-sm"
      classNames={{
        control: (state) => "border rounded p-1",
        multiValue: () => "bg-red-100 text-red-800",
        multiValueLabel: () => "font-medium",
        multiValueRemove: () => "hover:bg-red-200 cursor-pointer",
      }}
    />
  );
}
