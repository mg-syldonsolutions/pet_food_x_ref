export default function IngredientList({ items }) {
  return (
    <ul>
      {items.map((i) => (
        <li key={i.id}>
          {i.raw_text}{" "}
          {i.is_may_contain && "(may contain)"}{" "}
          {i.is_trace && "(trace)"}
        </li>
      ))}
    </ul>
  );
}
