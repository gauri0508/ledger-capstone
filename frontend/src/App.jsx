import { useCallback, useEffect, useState } from "react";
import { api } from "./api.js";

const CATEGORIES = ["food", "transport", "rent", "utilities", "shopping", "health", "fun", "other"];
const inr = new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", minimumFractionDigits: 2 });
const money = (v) => inr.format(Number(v));
const today = () => new Date().toISOString().slice(0, 10);

function SummaryStrip({ summary }) {
  const items = [
    { label: "This month", value: summary ? money(summary.month_total) : "–", hint: summary?.month },
    { label: "All time", value: summary ? money(summary.total) : "–" },
    { label: "Expenses", value: summary ? summary.count : "–" },
    { label: "Top category", value: summary?.top_category ?? "–" },
  ];
  return (
    <section className="summary">
      {items.map((it) => (
        <div className="stat" key={it.label}>
          <span className="stat-label">{it.label}</span>
          <span className="stat-value">{it.value}</span>
          {it.hint && <span className="stat-hint">{it.hint}</span>}
        </div>
      ))}
    </section>
  );
}

function ExpenseForm({ onAdd, busy }) {
  const [form, setForm] = useState({ amount: "", category: "food", note: "", spent_on: today() });
  const [error, setError] = useState(null);

  const set = (k) => (e) => setForm((f) => ({ ...f, [k]: e.target.value }));

  const submit = async (e) => {
    e.preventDefault();
    setError(null);
    try {
      await onAdd({ ...form, note: form.note || null });
      setForm((f) => ({ ...f, amount: "", note: "" }));
    } catch (err) {
      setError(err.message);
    }
  };

  return (
    <form className="card form" onSubmit={submit}>
      <h2>Add an expense</h2>
      <div className="fields">
        <label>
          Amount (INR)
          <input type="number" step="0.01" min="0.01" required placeholder="0.00" value={form.amount} onChange={set("amount")} />
        </label>
        <label>
          Category
          <select value={form.category} onChange={set("category")}>
            {CATEGORIES.map((c) => <option key={c} value={c}>{c}</option>)}
          </select>
        </label>
        <label>
          Date
          <input type="date" required value={form.spent_on} onChange={set("spent_on")} />
        </label>
        <label className="wide">
          Note
          <input type="text" maxLength={255} placeholder="optional" value={form.note} onChange={set("note")} />
        </label>
      </div>
      <div className="form-footer">
        {error && <span className="error">{error}</span>}
        <button type="submit" disabled={busy}>{busy ? "Saving…" : "Add expense"}</button>
      </div>
    </form>
  );
}

function ExpenseTable({ expenses, onDelete, filter, setFilter }) {
  return (
    <section className="card">
      <div className="table-head">
        <h2>Expenses</h2>
        <select value={filter} onChange={(e) => setFilter(e.target.value)} aria-label="filter by category">
          <option value="">all categories</option>
          {CATEGORIES.map((c) => <option key={c} value={c}>{c}</option>)}
        </select>
      </div>
      {expenses.length === 0 ? (
        <p className="empty">Nothing here yet. Add your first expense above.</p>
      ) : (
        <table>
          <thead>
            <tr><th>Date</th><th>Category</th><th>Note</th><th className="num">Amount</th><th></th></tr>
          </thead>
          <tbody>
            {expenses.map((e) => (
              <tr key={e.id}>
                <td>{e.spent_on}</td>
                <td><span className={`tag tag-${e.category}`}>{e.category}</span></td>
                <td className="note">{e.note || <span className="muted">—</span>}</td>
                <td className="num">{money(e.amount)}</td>
                <td className="actions"><button className="danger" onClick={() => onDelete(e.id)} title="delete">Delete</button></td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </section>
  );
}

export default function App() {
  const [expenses, setExpenses] = useState([]);
  const [summary, setSummary] = useState(null);
  const [filter, setFilter] = useState("");
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);
  const [version, setVersion] = useState(null);

  const refresh = useCallback(async () => {
    setError(null);
    try {
      const [list, sum] = await Promise.all([api.list(filter), api.summary()]);
      setExpenses(list);
      setSummary(sum);
    } catch (err) {
      setError(`Could not reach the API: ${err.message}`);
    } finally {
      setLoading(false);
    }
  }, [filter]);

  useEffect(() => { refresh(); }, [refresh]);
  useEffect(() => { api.version().then((v) => setVersion(v.version)).catch(() => {}); }, []);

  const add = async (expense) => {
    setBusy(true);
    try {
      await api.create(expense);
      await refresh();
    } finally {
      setBusy(false);
    }
  };

  const remove = async (id) => {
    try {
      await api.remove(id);
      await refresh();
    } catch (err) {
      setError(err.message);
    }
  };

  return (
    <div className="app">
      <header>
        <div>
          <h1>Ledger</h1>
          <p className="tagline">a small personal expense tracker</p>
        </div>
        {version && <span className="version">api v{version}</span>}
      </header>

      {error && <div className="banner error">{error} <button onClick={refresh}>retry</button></div>}

      <SummaryStrip summary={summary} />
      <ExpenseForm onAdd={add} busy={busy} />

      {loading ? (
        <section className="card"><p className="empty">Loading…</p></section>
      ) : (
        <ExpenseTable expenses={expenses} onDelete={remove} filter={filter} setFilter={setFilter} />
      )}

      <footer>Ledger · built by Gauri Shukla</footer>
    </div>
  );
}
