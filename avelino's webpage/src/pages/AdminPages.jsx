import { useRef, useState } from "react";
import {
  Package,
  ScanLine,
  History,
  Users,
  Search,
  Plus,
  Pencil,
  Archive,
  RotateCcw,
  ArrowRight,
  ChevronRight,
  Check,
  AlertCircle,
  PackageCheck,
  PackageOpen,
  ClockAlert,
  Eye,
  Filter,
  Boxes,
  QrCode,
  RefreshCw,
  CheckCircle2,
} from "lucide-react";
import { apiService } from "../services/apiService";
import {
  Badge,
  IconButton,
  Empty,
  Field,
  SearchBox,
  Modal,
  PageHead,
  ProductArt,
  StatCard,
  Loading,
} from "../components/ui";
import {
  pretty,
  dateInput,
  productOf,
  unitOf,
  isOverdue,
} from "../utils/domain";
import { ProductDetail } from "../components/ProductDetail";
import { ScanCapture } from "../components/ScanCapture";

export function AdminHome({
  products,
  units,
  loans,
  transactions,
  users,
  navigate,
  refresh,
  loading,
  dataError,
}) {
  const active = loans.filter((x) => x.status === "ACTIVE");
  const low = products.filter(
    (x) => x.availableUnits <= x.minimumStockLevel && !x.archived,
  );
  const stats = [
    [
      Package,
      "Product types",
      products.filter((x) => !x.archived).length,
      "amber",
    ],
    [
      Boxes,
      "Physical units",
      units.length,
      "blue",
    ],
    [
      PackageCheck,
      "Available",
      units.filter((unit) => unit.status === "AVAILABLE").length,
      "green",
    ],
    [
      PackageOpen,
      "Borrowed",
      units.filter((unit) => unit.status === "BORROWED").length,
      "amber",
    ],
    [
      AlertCircle,
      "Maintenance",
      units.filter((x) => x.status === "MAINTENANCE").length,
      "red",
    ],
    [ClockAlert, "Overdue", active.filter(isOverdue).length, "red"],
  ];
  return (
    <>
      <PageHead
        eyebrow="ADMIN / OVERVIEW"
        title="Inventory overview"
        description="A clear view of equipment, loans, and the work needing attention."
        action={
          <button
            className="button secondary"
            onClick={refresh}
            disabled={loading}
          >
            <RefreshCw size={17} className={loading ? "spin" : ""} /> Refresh
          </button>
        }
      />
      {dataError && <div className="inline-error" role="alert"><AlertCircle size={17} /> {dataError} <button onClick={refresh}>Retry</button></div>}
      <div className="stats-grid admin-stats">
        {stats.map(([Icon, label, value, tone]) => (
          <StatCard
            key={label}
            icon={Icon}
            label={label}
            value={value}
            tone={tone}
          />
        ))}
      </div>
      <div className="admin-home-grid">
        <section className="panel">
          <div className="panel-title">
            <div>
              <span className="eyebrow">RECENT ACTIVITY</span>
              <h2>Transactions</h2>
            </div>
            <button
              className="text-button"
              onClick={() => navigate("/admin/history")}
            >
              View history <ArrowRight size={16} />
            </button>
          </div>
          {transactions.length ? transactions.slice(0, 5).map((tx) => {
            const unit = units.find((x) => x.id === tx.unitId),
              product = productOf(unit, products),
              student = users.find((x) => x.id === tx.studentId);
            return (
              <button
                className="transaction-mini"
                key={tx.id}
                onClick={() => navigate("/admin/history")}
              >
                <span className={`activity-icon ${tx.type.toLowerCase()}`}>
                  {tx.type === "RECEIVE" ? (
                    <Plus size={17} />
                  ) : tx.type === "RETURN" ? (
                    <RotateCcw size={17} />
                  ) : (
                    <PackageCheck size={17} />
                  )}
                </span>
                <span>
                  <strong>
                    {tx.type === "ISSUE"
                      ? "Issued"
                      : tx.type === "RETURN"
                        ? "Returned"
                        : "Received"}{" "}
                    {product?.name}
                  </strong>
                  <small>
                    {student?.fullName || "Equipment office"} ·{" "}
                    {pretty(tx.timestamp)}
                  </small>
                </span>
                <ChevronRight size={16} />
              </button>
            );
          }) : <Empty title="No recent activity" />}
        </section>
        <section className="panel">
          <div className="panel-title">
            <div>
              <span className="eyebrow">ATTENTION NEEDED</span>
              <h2>Low stock</h2>
            </div>
            <Badge tone="warning">{low.length} items</Badge>
          </div>
          {low.length ? low.map((product) => (
            <button
              className="stock-row"
              key={product.id}
              onClick={() => navigate("/admin/products")}
            >
              <span className="stock-dot" />
              <span>
                <strong>{product.name}</strong>
                <small>
                  {product.category} · Minimum {product.minimumStockLevel}
                </small>
              </span>
              <Badge tone={product.availableUnits === 0 ? "danger" : "warning"}>
                {product.availableUnits} left
              </Badge>
            </button>
          )) : <Empty title="Stock is healthy" text="No products are at or below their minimum." />}
          <button
            className="text-button stock-report-link"
            onClick={() => navigate("/admin/products")}
          >
            Open low-stock report <ArrowRight size={16} />
          </button>
        </section>
      </div>
      <div className="panel">
        <div className="panel-title">
          <div>
            <span className="eyebrow">CURRENTLY OUT</span>
            <h2>Active loans</h2>
          </div>
          <button
            className="text-button"
            onClick={() => navigate("/admin/history")}
          >
            View all <ArrowRight size={16} />
          </button>
        </div>
        <div className="table-scroll">
          <table>
            <thead>
              <tr>
                <th>Loan</th>
                <th>Equipment</th>
                <th>Student</th>
                <th>Due</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              {active.map((loan) => {
                const unit = unitOf(loan, units),
                  product = productOf(unit, products),
                  student = users.find((x) => x.id === loan.studentId);
                return (
                  <tr key={loan.id} className="click-row">
                    <td><button className="table-row-link" onClick={() => navigate("/admin/history")}>{loan.loanNumber}</button></td>
                    <td>
                      <strong>{product?.name}</strong>
                      <small>{unit?.itemCode}</small>
                    </td>
                    <td>{student?.fullName}</td>
                    <td>{pretty(loan.expectedReturnAt)}</td>
                    <td>
                      <Badge tone={isOverdue(loan) ? "danger" : "warning"}>
                        {isOverdue(loan) ? "Overdue" : "Active"}
                      </Badge>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>
    </>
  );
}

export function ProductForm({ initial, existingProducts, onClose, onSave }) {
  const [form, setForm] = useState(
    initial || {
      equipmentId: "",
      name: "",
      category: "",
      description: "",
      minimumStockLevel: 1,
      quantityIntent: 0,
    },
  );
  const [error, setError] = useState("");
  const [saving, setSaving] = useState(false);
  const submit = async (event) => {
    event.preventDefault();
    if (saving) return;
    const minimum = Number(form.minimumStockLevel);
    const quantity = Number(form.quantityIntent ?? 0);
    if (
      !form.equipmentId.trim() ||
      !form.name.trim() ||
      !form.category.trim() ||
      !form.description.trim() ||
      form.minimumStockLevel === "" ||
      !Number.isSafeInteger(minimum) || minimum < 0 ||
      !Number.isSafeInteger(quantity) || quantity < 0
    ) {
      setError("Complete every field with non-negative whole stock values.");
      return;
    }
    if (existingProducts.some((product) =>
      product.id !== initial?.id &&
      product.equipmentId.toLowerCase() === form.equipmentId.trim().toLowerCase()
    )) {
      setError("Equipment ID already exists. Enter a unique ID.");
      return;
    }
    setSaving(true);
    try {
      await onSave({
        ...form,
        equipmentId: form.equipmentId.trim(),
        name: form.name.trim(),
        category: form.category.trim(),
        description: form.description.trim(),
        minimumStockLevel: minimum,
        quantityIntent: quantity,
      });
    } catch (saveError) {
      setError(saveError.message || "Could not validate this product. Try again.");
    } finally {
      setSaving(false);
    }
  };
  return (
    <Modal title={initial ? "Edit product" : "Add product"} onClose={onClose}>
      <form onSubmit={submit} className="modal-form">
        <div className="form-grid">
          <Field label="Equipment ID" required>
            <input
              value={form.equipmentId}
              readOnly={Boolean(initial)}
              onChange={(e) =>
                setForm({ ...form, equipmentId: e.target.value })
              }
              placeholder="CAM-001"
            />
          </Field>
          <Field label="Category" required>
            <input
              value={form.category}
              onChange={(e) => setForm({ ...form, category: e.target.value })}
              placeholder="Cameras"
            />
          </Field>
        </div>
        <Field label="Product name" required>
          <input
            value={form.name}
            onChange={(e) => setForm({ ...form, name: e.target.value })}
            placeholder="Camera model"
          />
        </Field>
        <Field label="Description" required>
          <textarea
            rows="3"
            value={form.description}
            onChange={(e) => setForm({ ...form, description: e.target.value })}
          />
        </Field>
        <div className="form-grid">
          <Field label="Minimum available stock" required>
            <input
              type="number"
              min="0"
              value={form.minimumStockLevel}
              onChange={(e) =>
                setForm({ ...form, minimumStockLevel: e.target.value })
              }
            />
          </Field>
          <Field label="Quantity intent" hint="Does not create stock.">
            <input
              type="number"
              min="0"
              value={form.quantityIntent || 0}
              onChange={(e) =>
                setForm({ ...form, quantityIntent: e.target.value })
              }
            />
          </Field>
        </div>
        {error && (
          <div className="inline-error">
            <AlertCircle size={17} />
            {error}
          </div>
        )}
        <div className="modal-actions">
          <button type="button" className="button secondary" onClick={onClose}>
            Cancel
          </button>
          <button className="button" disabled={saving}>
            {saving ? "Saving…" : `Save ${initial ? "changes" : "product"}`} <Check size={17} />
          </button>
        </div>
      </form>
    </Modal>
  );
}

export function AdminProducts({
  products,
  setProducts,
  units,
  navigate,
  notify,
  refresh,
}) {
  const [search, setSearch] = useState(""),
    [category, setCategory] = useState("All"),
    [sort, setSort] = useState("name"),
    [showLow, setShowLow] = useState(
      () => new URLSearchParams(window.location.search).get("lowStock") === "1",
    ),
    [showArchived, setShowArchived] = useState(false),
    [selected, setSelected] = useState(null),
    [editing, setEditing] = useState(undefined),
    [archive, setArchive] = useState(null);
  const categories = ["All", ...new Set(products.map((x) => x.category))];
  const shown = products
    .filter(
      (x) =>
        (showArchived || !x.archived) &&
        (!showLow || x.availableUnits <= x.minimumStockLevel) &&
        (category === "All" || x.category === category) &&
        `${x.name} ${x.equipmentId} ${x.category}`
          .toLowerCase()
          .includes(search.toLowerCase()),
    )
    .sort((a, b) =>
      sort === "name"
        ? a.name.localeCompare(b.name)
        : sort === "available"
          ? a.availableUnits - b.availableUnits
          : a.category.localeCompare(b.category),
    );
  const save = async (item) => {
    const response = await apiService.saveProduct(item);
    if (!response.ok) throw new Error(response.error?.message || "Could not save this product.");
    if (editing)
      setProducts((old) =>
        old.map((x) => (x.id === editing.id ? response.data : x)),
      );
    else
      setProducts((old) => [...old, response.data]);
    await refresh();
    notify("Product saved to ENcoRE.");
    setEditing(undefined);
  };
  return (
    <>
      <PageHead
        eyebrow="ADMIN / INVENTORY"
        title="Products & units"
        description="Manage product types and inspect their individually coded physical units."
        action={
          <div className="action-row">
            <button
              className="button secondary"
              onClick={() => navigate("/admin/scan")}
            >
              <ScanLine size={17} /> Receive units
            </button>
            <button className="button" onClick={() => setEditing(null)}>
              <Plus size={17} /> Add product
            </button>
          </div>
        }
      />
      <div className="inventory-toolbar">
        <SearchBox
          value={search}
          onChange={setSearch}
          placeholder="Search name or equipment ID"
        />
        <select
          aria-label="Category filter"
          value={category}
          onChange={(e) => setCategory(e.target.value)}
        >
          {categories.map((x) => (
            <option key={x}>{x}</option>
          ))}
        </select>
        <select
          aria-label="Sort products"
          value={sort}
          onChange={(e) => setSort(e.target.value)}
        >
          <option value="name">Sort: Name</option>
          <option value="available">Sort: Available</option>
          <option value="category">Sort: Category</option>
        </select>
        <button
          className={`button secondary ${showLow ? "active-filter" : ""}`}
          aria-pressed={showLow}
          onClick={() => setShowLow(!showLow)}
        >
          <Filter size={16} /> Low stock
        </button>
        <label className="inline-check">
          <input
            type="checkbox"
            checked={showArchived}
            onChange={(e) => setShowArchived(e.target.checked)}
          />{" "}
          Archived
        </label>
      </div>
      <div className="panel product-table-panel">
        <div className="panel-title">
          <div>
            <span className="eyebrow">CATALOG</span>
            <h2>{showLow ? "Low-stock report" : "All products"}</h2>
          </div>
          <span className="muted">{shown.length} product types</span>
        </div>
        {shown.length ? (
          <div className="table-scroll">
            <table>
              <thead>
                <tr>
                  <th>Product</th>
                  <th>Equipment ID</th>
                  <th>Category</th>
                  <th>Units</th>
                  <th>Available</th>
                  <th>Status</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {shown.map((product) => (
                  <tr key={product.id}>
                    <td>
                      <div className="table-product">
                        <ProductArt product={product} />
                        <span>
                          <strong>{product.name}</strong>
                          <small>{product.description}</small>
                        </span>
                      </div>
                    </td>
                    <td>{product.equipmentId}</td>
                    <td>{product.category}</td>
                    <td>{product.totalUnits}</td>
                    <td>{product.availableUnits}</td>
                    <td>
                      <Badge
                        tone={
                          product.archived
                            ? "neutral"
                            : product.availableUnits <=
                                product.minimumStockLevel
                              ? "warning"
                              : "success"
                        }
                      >
                        {product.archived
                          ? "Archived"
                          : product.availableUnits <= product.minimumStockLevel
                            ? "Low stock"
                            : "Healthy"}
                      </Badge>
                    </td>
                    <td>
                      <div className="table-actions">
                        <IconButton
                          icon={Eye}
                          label={`View ${product.name}`}
                          onClick={() => setSelected(product)}
                        />
                        <IconButton
                          icon={Pencil}
                          label={`Edit ${product.name}`}
                          onClick={() => setEditing(product)}
                        />
                        <IconButton
                          icon={Archive}
                          label={`${product.archived ? "Restore" : "Archive"} ${product.name}`}
                          onClick={() => setArchive(product)}
                        />
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <Empty
            icon={Search}
            title="No products match"
            text="Try clearing a filter or search."
          />
        )}
      </div>
      {selected && (
        <ProductDetail
          product={selected}
          units={units}
          onClose={() => setSelected(null)}
          navigate={navigate}
          admin
        />
      )}
      {editing !== undefined && (
        <ProductForm
          initial={editing}
          existingProducts={products}
          onClose={() => setEditing(undefined)}
          onSave={save}
        />
      )}
      {archive && (
        <Modal
          title={archive.archived ? "Restore product?" : "Archive product?"}
          onClose={() => setArchive(null)}
        >
          <p className="modal-copy">
            {archive.name} will be{" "}
            {archive.archived ? "restored to the active catalog" : "hidden from the active catalog"}. Existing loan records remain visible.
          </p>
          <div className="modal-actions">
            <button
              className="button secondary"
              onClick={() => setArchive(null)}
            >
              Cancel
            </button>
            <button
              className="button"
              onClick={async () => {
                const response = await apiService.saveProduct({ ...archive, archived: !archive.archived });
                if (!response.ok) { notify(response.error?.message || "Could not update product.", "error"); return; }
                await refresh();
                notify("Catalog updated.");
                setArchive(null);
              }}
            >
              {archive.archived ? "Restore product" : "Archive product"}
            </button>
          </div>
        </Modal>
      )}
    </>
  );
}

export function ReceiveMode({ products, units, notify, code, setCode, refresh }) {
  const [productId, setProductId] = useState(products.find((item) => !item.archived)?.id || ""),
    [quantity, setQuantity] = useState(1),
    [date, setDate] = useState(dateInput().slice(0, 10)),
    [started, setStarted] = useState(false),
    [entries, setEntries] = useState([]),
    [serial, setSerial] = useState(""),
    [error, setError] = useState(""),
    [busy, setBusy] = useState(false);
  const start = () => {
    if (
      !products.some((item) => item.id === productId && !item.archived) ||
      !Number.isInteger(Number(quantity)) ||
      Number(quantity) <= 0 ||
      !date ||
      isNaN(new Date(date))
    ) {
      setError(
        "Select a product, positive whole quantity, and valid registration date.",
      );
      return;
    }
    setEntries([]);
    setStarted(true);
    setError("");
  };
  const add = async (event) => {
    event.preventDefault();
    const c = code.trim().toUpperCase(),
      s = serial.trim().toUpperCase();
    if (!c || !s) {
      setError("Enter both item code and serial number.");
      return;
    }
    if (
      units.some((x) => x.itemCode.toUpperCase() === c) ||
      entries.some((x) => x.itemCode === c)
    ) {
      setError(
        "Duplicate item code. Enter a unique code; progress is unchanged.",
      );
      return;
    }
    if (
      units.some((x) => x.serialNumber.toUpperCase() === s) ||
      entries.some((x) => x.serialNumber === s)
    ) {
      setError(
        "Duplicate serial number. Enter a unique serial; progress is unchanged.",
      );
      return;
    }
    setBusy(true);
    try {
      const response = await apiService.receiveUnit({
        productId,
        itemCode: c,
        serialNumber: s,
        receivedAt: date,
      });
      if (!response.ok) throw new Error(response.error?.message || "Could not validate this unit.");
      await refresh();
      setEntries((current) => [...current, { itemCode: c, serialNumber: s }]);
      setCode("");
      setSerial("");
      setError("");
      notify(`Unit ${entries.length + 1} of ${quantity} registered.`);
    } catch (receiveError) {
      setError(receiveError.message || "Could not validate this unit. Try again.");
    } finally {
      setBusy(false);
    }
  };
  const done = entries.length >= Number(quantity);
  return (
    <div className="scan-layout">
      <div className="panel">
        <div className="panel-title">
          <div>
            <span className="eyebrow">REGISTER / RECEIVE</span>
            <h2>Receive physical units</h2>
          </div>
          <Badge tone="success">Live inventory</Badge>
        </div>
        <p className="panel-intro">
          Select a product, then register each physical unit with its own code
          and serial number.
        </p>
        <div className="form-grid">
          <Field label="Product" required>
            <select
              disabled={started}
              value={productId}
              onChange={(e) => setProductId(e.target.value)}
            >
              {products
                .filter((x) => !x.archived)
                .map((x) => (
                  <option value={x.id} key={x.id}>
                    {x.name} · {x.equipmentId}
                  </option>
                ))}
            </select>
          </Field>
          <Field label="Quantity" required>
            <input
              type="number"
              min="1"
              step="1"
              disabled={started}
              value={quantity}
              onChange={(e) => setQuantity(e.target.value)}
            />
          </Field>
        </div>
        <Field label="Registration date" required>
          <input
            type="date"
            disabled={started}
            value={date}
            onChange={(e) => setDate(e.target.value)}
          />
        </Field>
        {!started ? (
          <button className="button wide" onClick={start}>
            Start unit registration <ArrowRight size={17} />
          </button>
        ) : (
          <>
            <div className="progress-head">
              <strong>
                {entries.length} of {quantity} registered
              </strong>
              <span>
                {Math.round((entries.length / Number(quantity)) * 100)}%
              </span>
            </div>
            <div className="progress-track">
              <span
                style={{
                  width: `${Math.min(100, (entries.length / Number(quantity)) * 100)}%`,
                }}
              />
            </div>
            {done ? (
              <div className="callout success-callout">
                <CheckCircle2 size={20} /> All units were registered in ENcoRE.
              </div>
            ) : (
              <form onSubmit={add}>
                <div className="form-grid">
                  <Field label="Item code" required>
                    <input
                      value={code}
                      onChange={(e) => setCode(e.target.value)}
                      placeholder="CAM-R50-006"
                    />
                  </Field>
                  <Field label="Serial number" required>
                    <input
                      value={serial}
                      onChange={(e) => setSerial(e.target.value)}
                      placeholder="CR50-847206"
                    />
                  </Field>
                </div>
                <button className="button wide" disabled={busy}>
                  {busy
                    ? "Checking…"
                    : `Register unit ${entries.length + 1} of ${quantity}`}{" "}
                  <Plus size={17} />
                </button>
              </form>
            )}
            <button
              className="text-button reset-registration"
              onClick={() => {
                setStarted(false);
                setEntries([]);
                setError("");
              }}
            >
              Start a different batch
            </button>
          </>
        )}
        {error && (
          <div className="inline-error">
            <AlertCircle size={17} />
            {error}
          </div>
        )}
      </div>
      <div className="panel">
        <div className="panel-title">
          <div>
            <span className="eyebrow">BATCH PREVIEW</span>
            <h2>Registration progress</h2>
          </div>
        </div>
        {entries.length ? (
          <div className="unit-list">
            {entries.map((x, i) => (
              <div className="unit-row" key={x.itemCode}>
                <span className="unit-code">
                  <CheckCircle2 size={17} /> {i + 1}. {x.itemCode}
                </span>
                <span className="muted">{x.serialNumber}</span>
                <Badge tone="warning">Preview</Badge>
              </div>
            ))}
          </div>
        ) : (
          <Empty
            icon={QrCode}
            title="No units registered yet"
            text="Start a batch and enter the first physical unit."
          />
        )}
      </div>
    </div>
  );
}

export function IssueMode({ products, users, notify, refresh }) {
  const [studentId, setStudentId] = useState(""),
    [unit, setUnit] = useState(null),
    [due, setDue] = useState(""),
    [error, setError] = useState(""),
    [step, setStep] = useState("capture"),
    [borrowAt, setBorrowAt] = useState(null),
    [busy, setBusy] = useState(false);
  const lookupSequence = useRef(0);
  const students = users.filter(
    (x) => x.role === "STUDENT" && x.accountStatus === "Active",
  );
  const student = students.find((x) => x.id === studentId);
  const lookup = async (code) => {
    const sequence = ++lookupSequence.current;
    setBusy(true);
    setError("");
    setStep("capture");
    setUnit(null);
    setDue("");
    setBorrowAt(null);
    try {
      const response = await apiService.lookupUnit(code);
      if (sequence !== lookupSequence.current) return;
      if (!response.ok) throw new Error(response.error?.message || "Could not find this unit.");
      setUnit(response.data);
      if (response.data.status !== "AVAILABLE")
        setError("This unit is unavailable. Issue is blocked until it is available.");
    } catch (lookupError) {
      if (sequence !== lookupSequence.current) return;
      setUnit(null);
      setError(lookupError.message || "Could not find this unit. Try again.");
    } finally {
      if (sequence === lookupSequence.current) setBusy(false);
    }
  };
  const review = () => {
    const now = new Date();
    if (!student) {
      setError("Select an active student.");
      return;
    }
    if (!unit || unit.status !== "AVAILABLE") {
      setError("Scan an available physical unit.");
      return;
    }
    if (!due || isNaN(new Date(due)) || new Date(due) <= now) {
      setError("Choose a valid due time later than the displayed issue time.");
      return;
    }
    setBorrowAt(now.toISOString());
    setError("");
    setStep("review");
  };
  const confirm = async () => {
    if (busy) return;
    setBusy(true);
    try {
      const response = await apiService.adminIssue({ unitId: unit.id, dueAt: due, borrowerId: student.id });
      if (!response.ok) throw new Error(response.error?.message || "Could not complete the issue review.");
      setStep("done");
      await refresh();
      notify("Loan issued and saved to ENcoRE.");
    } catch (issueError) {
      setError(issueError.message || "Could not complete the issue review. Try again.");
    } finally {
      setBusy(false);
    }
  };
  const product = productOf(unit, products);
  return (
    <div className="scan-layout">
      <div className="panel">
        <div className="panel-title">
          <div>
            <span className="eyebrow">ISSUE EQUIPMENT</span>
            <h2>Choose student & unit</h2>
          </div>
        </div>
        <Field label="Active student" required>
          <select
            value={studentId}
            onChange={(e) => setStudentId(e.target.value)}
          >
            <option value="">Select a student</option>
            {students.map((x) => (
              <option value={x.id} key={x.id}>
                {x.fullName} · {x.studentId}
              </option>
            ))}
          </select>
        </Field>
        <ScanCapture onCode={lookup} />
        {busy && <Loading />}
        {error && (
          <div className="inline-error">
            <AlertCircle size={17} />
            {error}
          </div>
        )}
      </div>
      <div className="panel">
        <div className="panel-title">
          <div>
            <span className="eyebrow">ISSUE REVIEW</span>
            <h2>{step === "done" ? "Issue result" : "Loan details"}</h2>
          </div>
        </div>
        {step === "done" ? (
          <div className="result-success">
            <span className="success-emblem">
              <Check size={30} />
            </span>
            <h3>Issue completed</h3>
            <p>The loan and receipt were saved in ENcoRE.</p>
            <button
              className="button wide"
              onClick={() => {
                setUnit(null);
                setDue("");
                setStep("capture");
                setError("");
              }}
            >
              Issue another item
            </button>
          </div>
        ) : !unit ? (
          <Empty
            icon={PackageOpen}
            title="Select a student and scan a unit"
            text="The exact item and loan review will appear here."
          />
        ) : (
          <>
            <div className="exact-item">
              <ProductArt product={product} />
              <div>
                <span className="eyebrow">{product?.category}</span>
                <h3>{product?.name}</h3>
                <span className="muted">
                  {unit.itemCode} · {unit.serialNumber}
                </span>
              </div>
            </div>
            <div className="details-list">
              <div>
                <span>Unit status</span>
                <Badge
                  tone={unit.status === "AVAILABLE" ? "success" : "danger"}
                >
                  {unit.status}
                </Badge>
              </div>
              <div>
                <span>Student</span>
                <strong>{student?.fullName || "Select student"}</strong>
              </div>
            </div>
            {step === "review" ? (
              <>
                <div className="review-box">
                  <h3>Confirm issue</h3>
                  <div>
                    <span>Student</span>
                    <strong>
                      {student?.fullName} · {student?.studentId}
                    </strong>
                  </div>
                  <div>
                    <span>Product</span>
                    <strong>
                      {product?.name} · {product?.category}
                    </strong>
                  </div>
                  <div>
                    <span>Exact unit</span>
                    <strong>
                      {unit.itemCode} · {unit.serialNumber}
                    </strong>
                  </div>
                  <div>
                    <span>Issue time</span>
                    <strong>{pretty(borrowAt)}</strong>
                  </div>
                  <div>
                    <span>Expected return</span>
                    <strong>{pretty(due)}</strong>
                  </div>
                </div>
                <div className="action-row">
                  <button
                    className="button secondary"
                    onClick={() => setStep("capture")}
                  >
                    Back
                  </button>
                  <button className="button" onClick={confirm} disabled={busy}>
                    Confirm issue <Check size={17} />
                  </button>
                </div>
              </>
            ) : (
              <>
                <Field label="Expected return date and time" required>
                  <input
                    type="datetime-local"
                    min={dateInput()}
                    value={due}
                    onChange={(e) => setDue(e.target.value)}
                  />
                </Field>
                <button
                  className="button wide"
                  disabled={unit.status !== "AVAILABLE"}
                  onClick={review}
                >
                  Review issue <ArrowRight size={17} />
                </button>
              </>
            )}
          </>
        )}
      </div>
    </div>
  );
}

export function ReturnMode({ products, loans, users, notify, refresh }) {
  const [unit, setUnit] = useState(null),
    [loan, setLoan] = useState(null),
    [condition, setCondition] = useState("Good"),
    [time, setTime] = useState(dateInput()),
    [error, setError] = useState(""),
    [step, setStep] = useState("capture"),
    [busy, setBusy] = useState(false);
  const lookupSequence = useRef(0);
  const lookup = async (code) => {
    const sequence = ++lookupSequence.current;
    setBusy(true);
    setError("");
    setStep("capture");
    setUnit(null);
    setLoan(null);
    setTime(dateInput());
    setCondition("Good");
    try {
      const response = await apiService.lookupUnit(code);
      if (sequence !== lookupSequence.current) return;
      if (!response.ok) throw new Error(response.error?.message || "Could not find this unit.");
      const active = loans.find(
        (x) => x.unitId === response.data.id && x.status === "ACTIVE",
      );
      setUnit(response.data);
      setLoan(active || null);
      if (!active)
        setError("No active loan matches this item. It may already have been returned or was never issued.");
    } catch (lookupError) {
      if (sequence !== lookupSequence.current) return;
      setUnit(null);
      setLoan(null);
      setError(lookupError.message || "Could not find this unit. Try again.");
    } finally {
      if (sequence === lookupSequence.current) setBusy(false);
    }
  };
  const review = () => {
    if (!loan) {
      setError("A matching active loan is required.");
      return;
    }
    if (
      !time ||
      isNaN(new Date(time)) ||
      new Date(time) < new Date(loan.borrowedAt) ||
      new Date(time) > new Date(Date.now() + 60000)
    ) {
      setError(
        "Choose an actual return time after borrowing and no later than now.",
      );
      return;
    }
    setError("");
    setStep("review");
  };
  const confirm = async () => {
    if (busy) return;
    setBusy(true);
    try {
      const response = await apiService.adminReturn({ itemCode: unit.itemCode, returnedAt: time, condition });
      if (!response.ok) throw new Error(response.error?.message || "Could not complete the return review.");
      setStep("done");
      await refresh();
      notify("Return recorded in ENcoRE.");
    } catch (returnError) {
      setError(returnError.message || "Could not complete the return review. Try again.");
      setStep("capture");
    } finally {
      setBusy(false);
    }
  };
  const product = productOf(unit, products),
    student = users.find((x) => x.id === loan?.studentId);
  return (
    <div className="scan-layout">
      <div className="panel">
        <div className="panel-title">
          <div>
            <span className="eyebrow">PROCESS RETURN</span>
            <h2>Scan returned item</h2>
          </div>
        </div>
        <ScanCapture onCode={lookup} />
        {busy && <Loading />}
        {error && (
          <div className="inline-error">
            <AlertCircle size={17} />
            {error}
          </div>
        )}
      </div>
      <div className="panel">
        <div className="panel-title">
          <div>
            <span className="eyebrow">RETURN REVIEW</span>
            <h2>{step === "done" ? "Return result" : "Active loan"}</h2>
          </div>
        </div>
        {step === "done" ? (
          <div className="result-success">
            <span className="success-emblem">
              <Check size={30} />
            </span>
            <h3>Return completed</h3>
            <p>
              Expected outcome:{" "}
              <strong>
                {condition === "Good" ? "Available" : "Maintenance"}
              </strong>
              . The loan and inventory record were updated.
            </p>
            <button
              className="button wide"
              onClick={() => {
                setUnit(null);
                setLoan(null);
                setStep("capture");
                setError("");
              }}
            >
              Process another return
            </button>
          </div>
        ) : !loan ? (
          <Empty
            icon={RotateCcw}
            title="No active loan selected"
            text="Scan the code of an issued unit to find its matching loan."
          />
        ) : (
          <>
            <div className="exact-item">
              <ProductArt product={product} />
              <div>
                <span className="eyebrow">{loan.loanNumber}</span>
                <h3>{product?.name}</h3>
                <span className="muted">
                  {unit?.itemCode} · {unit?.serialNumber}
                </span>
              </div>
            </div>
            <div className="details-list">
              <div>
                <span>Student</span>
                <strong>
                  {student?.fullName} · {student?.studentId}
                </strong>
              </div>
              <div>
                <span>Borrowed</span>
                <strong>{pretty(loan.borrowedAt)}</strong>
              </div>
              <div>
                <span>Due</span>
                <strong>{pretty(loan.expectedReturnAt)}</strong>
              </div>
            </div>
            {step === "review" ? (
              <>
                <div className="review-box">
                  <h3>Confirm return</h3>
                  <div>
                    <span>Actual return</span>
                    <strong>{pretty(time)}</strong>
                  </div>
                  <div>
                    <span>Condition</span>
                    <strong>{condition}</strong>
                  </div>
                  <div>
                    <span>Expected unit status</span>
                    <Badge tone={condition === "Good" ? "success" : "danger"}>
                      {condition === "Good" ? "Available" : "Maintenance"}
                    </Badge>
                  </div>
                </div>
                <div className="action-row">
                  <button
                    className="button secondary"
                    onClick={() => setStep("capture")}
                  >
                    Back
                  </button>
                  <button className="button" onClick={confirm} disabled={busy}>
                    Confirm return <Check size={17} />
                  </button>
                </div>
              </>
            ) : (
              <>
                <Field label="Actual return time" required>
                  <input
                    type="datetime-local"
                    value={time}
                    max={dateInput()}
                    onChange={(e) => setTime(e.target.value)}
                  />
                </Field>
                <div className="field">
                  <label>
                    Item condition <span className="required">*</span>
                  </label>
                  <div className="condition-options">
                    {["Good", "Needs Maintenance"].map((x) => (
                      <label
                        key={x}
                        className={condition === x ? "selected" : ""}
                      >
                        <input
                          type="radio"
                          name="condition"
                          value={x}
                          checked={condition === x}
                          onChange={() => setCondition(x)}
                        />
                        {x}
                      </label>
                    ))}
                  </div>
                </div>
                <button className="button wide" onClick={review}>
                  Review return <ArrowRight size={17} />
                </button>
              </>
            )}
          </>
        )}
      </div>
    </div>
  );
}

export function AdminScan({ products, units, loans, users, notify, refresh }) {
  const [mode, setMode] = useState("Receive"),
    [capturedCode, setCapturedCode] = useState(""),
    [showCapture, setShowCapture] = useState(false);
  return (
    <>
      <PageHead
        eyebrow="ADMIN / SCAN DESK"
        title="Scan & process"
        description="Register new units, issue equipment, and process returns."
      />
      <div className="mode-tabs" role="tablist" aria-label="Scan mode">
        {[
          [Plus, "Receive"],
          [PackageCheck, "Issue"],
          [RotateCcw, "Return"],
        ].map(([Icon, name]) => (
          <button
            key={name}
            role="tab"
            aria-selected={mode === name}
            aria-controls="scan-mode-panel"
            tabIndex={mode === name ? 0 : -1}
            className={mode === name ? "active" : ""}
            onClick={() => setMode(name)}
            onKeyDown={(event) => {
              const tabs = [...event.currentTarget.parentElement.querySelectorAll('[role="tab"]')];
              const index = tabs.indexOf(event.currentTarget);
              const nextIndex = event.key === "ArrowRight"
                ? (index + 1) % tabs.length
                : event.key === "ArrowLeft"
                  ? (index - 1 + tabs.length) % tabs.length
                  : event.key === "Home"
                    ? 0
                    : event.key === "End" ? tabs.length - 1 : -1;
              if (nextIndex < 0) return;
              event.preventDefault();
              tabs[nextIndex].focus();
              setMode(["Receive", "Issue", "Return"][nextIndex]);
            }}
          >
            <Icon size={18} />{" "}
            {name === "Receive"
              ? "Register / Receive"
              : name === "Issue"
                ? "Issue to Student"
                : "Process Return"}
          </button>
        ))}
      </div>
      <div className="mode-content" key={mode} id="scan-mode-panel" role="tabpanel" aria-label={`${mode} workflow`}>
      {mode === "Receive" ? (
        <>
          {showCapture && (
            <div className="panel receive-capture">
              <div className="panel-title">
                <h2>Capture a new unit code</h2>
                <button
                  className="text-button"
                  onClick={() => setShowCapture(false)}
                >
                  Close
                </button>
              </div>
              <ScanCapture
                label="New item code"
                actionLabel="Use code in batch"
                onCode={(value) => {
                  setCapturedCode(value);
                  setShowCapture(false);
                  notify(`Code ${value} added to the registration form.`);
                }}
              />
            </div>
          )}
          <button
            className="button secondary receive-capture-toggle"
            onClick={() => setShowCapture(!showCapture)}
          >
            <ScanLine size={17} />{" "}
            {showCapture
              ? "Hide camera / manual capture"
              : "Open camera / manual code capture"}
          </button>
          <ReceiveMode
            products={products}
            units={units}
            notify={notify}
            code={capturedCode}
            setCode={setCapturedCode}
            refresh={refresh}
          />
        </>
      ) : mode === "Issue" ? (
        <IssueMode products={products} users={users} notify={notify} refresh={refresh} />
      ) : (
        <ReturnMode products={products} loans={loans} users={users} notify={notify} refresh={refresh} />
      )}
      </div>
    </>
  );
}

export function AdminHistory({ transactions, units, products, loans, users }) {
  const requestedStatus = new URLSearchParams(window.location.search).get("status");
  const [search, setSearch] = useState(""),
    [type, setType] = useState("All"),
    [status, setStatus] = useState(
      ["Active", "Returned", "Overdue", "None"].includes(requestedStatus)
        ? requestedStatus
        : "All",
    ),
    [student, setStudent] = useState("All"),
    [date, setDate] = useState(""),
    [sort, setSort] = useState("newest"),
    [selected, setSelected] = useState(null);
  const shown = transactions
    .filter((tx) => {
      const unit = units.find((x) => x.id === tx.unitId),
        product = productOf(unit, products),
        person = users.find((x) => x.id === tx.studentId),
        loan = loans.find((x) => x.id === tx.loanId);
      const haystack =
        `${product?.name} ${product?.equipmentId} ${unit?.itemCode} ${person?.fullName} ${person?.studentId}`.toLowerCase();
      return (
        haystack.includes(search.toLowerCase()) &&
        (type === "All" || tx.type === type) &&
        (status === "All" ||
          (loan
            ? isOverdue(loan)
              ? status === "Overdue"
              : loan.status === status.toUpperCase()
            : status === "None")) &&
        (student === "All" || tx.studentId === student) &&
        (!date || tx.timestamp.slice(0, 10) === date)
      );
    })
    .sort((a, b) =>
      sort === "newest"
        ? new Date(b.timestamp) - new Date(a.timestamp)
        : new Date(a.timestamp) - new Date(b.timestamp),
    );
  return (
    <>
      <PageHead
        eyebrow="ADMIN / HISTORY"
        title="Transaction history"
        description="Review receiving, issue, and return activity across the equipment office."
      />
      <div className="panel">
        <div className="filter-grid">
          <SearchBox
            value={search}
            onChange={setSearch}
            placeholder="Search equipment, code, or student"
          />
          <select
            value={type}
            onChange={(e) => setType(e.target.value)}
            aria-label="Transaction type"
          >
            <option>All</option>
            <option>RECEIVE</option>
            <option>ISSUE</option>
            <option>RETURN</option>
          </select>
          <select
            value={status}
            onChange={(e) => setStatus(e.target.value)}
            aria-label="Loan status"
          >
            <option>All</option>
            <option>Active</option>
            <option>Returned</option>
            <option>Overdue</option>
            <option>None</option>
          </select>
          <select
            value={student}
            onChange={(e) => setStudent(e.target.value)}
            aria-label="Student"
          >
            <option value="All">All students</option>
            {users
              .filter((x) => x.role === "STUDENT")
              .map((x) => (
                <option value={x.id} key={x.id}>
                  {x.fullName}
                </option>
              ))}
          </select>
          <input
            type="date"
            className={date ? undefined : "date-empty"}
            value={date}
            onChange={(e) => setDate(e.target.value)}
            aria-label="Transaction date"
          />
          <select
            value={sort}
            onChange={(e) => setSort(e.target.value)}
            aria-label="Sort transactions"
          >
            <option value="newest">Newest first</option>
            <option value="oldest">Oldest first</option>
          </select>
        </div>
        <div className="panel-title table-title">
          <div>
            <span className="eyebrow">AUDIT TRAIL</span>
            <h2>Transactions</h2>
          </div>
          <span className="muted">{shown.length} records</span>
        </div>
        {shown.length ? (
          <div className="table-scroll">
            <table>
              <thead>
                <tr>
                  <th>Event</th>
                  <th>Equipment</th>
                  <th>Item code</th>
                  <th>Student</th>
                  <th>Date & time</th>
                  <th>Loan status</th>
                </tr>
              </thead>
              <tbody>
                {shown.map((tx) => {
                  const unit = units.find((x) => x.id === tx.unitId),
                    product = productOf(unit, products),
                    person = users.find((x) => x.id === tx.studentId),
                    loan = loans.find((x) => x.id === tx.loanId);
                  return (
                    <tr key={tx.id} className="click-row">
                      <td>
                        <button className="table-row-link" onClick={() => setSelected(tx)} aria-label={`View ${tx.type.toLowerCase()} transaction for ${product?.name || "equipment"}`}><Badge
                          tone={
                            tx.type === "RETURN"
                              ? "success"
                              : tx.type === "RECEIVE"
                                ? "neutral"
                                : "warning"
                          }
                        >
                          {tx.type}
                        </Badge></button>
                      </td>
                      <td>
                        <strong>{product?.name}</strong>
                        <small>{product?.equipmentId}</small>
                      </td>
                      <td>{unit?.itemCode}</td>
                      <td>{person?.fullName || "—"}</td>
                      <td>{pretty(tx.timestamp)}</td>
                      <td>
                        {loan ? (
                          <Badge
                            tone={
                              isOverdue(loan)
                                ? "danger"
                                : loan.status === "RETURNED"
                                  ? "success"
                                  : "warning"
                            }
                          >
                            {isOverdue(loan) ? "Overdue" : loan.status}
                          </Badge>
                        ) : (
                          "—"
                        )}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        ) : (
          <Empty
            icon={History}
            title="No matching transactions"
            text="Adjust the search or filters."
          />
        )}
      </div>
      {selected &&
        (() => {
          const unit = units.find((x) => x.id === selected.unitId),
            product = productOf(unit, products),
            person = users.find((x) => x.id === selected.studentId),
            loan = loans.find((x) => x.id === selected.loanId);
          return (
            <Modal
              title="Transaction details"
              onClose={() => setSelected(null)}
            >
              <div className="details-list">
                <div>
                  <span>Type</span>
                  <Badge tone="warning">{selected.type}</Badge>
                </div>
                <div>
                  <span>Timestamp</span>
                  <strong>{pretty(selected.timestamp)}</strong>
                </div>
                <div>
                  <span>Product</span>
                  <strong>
                    {product?.name} · {product?.equipmentId}
                  </strong>
                </div>
                <div>
                  <span>Item</span>
                  <strong>
                    {unit?.itemCode} · {unit?.serialNumber}
                  </strong>
                </div>
                <div>
                  <span>Student</span>
                  <strong>{person?.fullName || "—"}</strong>
                </div>
                <div>
                  <span>Loan</span>
                  <strong>{loan?.loanNumber || "—"}</strong>
                </div>
                <div>
                  <span>Operator</span>
                  <strong>
                    {users.find((x) => x.id === selected.operatorId)
                      ?.fullName || "—"}
                  </strong>
                </div>
                <div>
                  <span>Remarks</span>
                  <strong>{selected.remarks}</strong>
                </div>
              </div>
            </Modal>
          );
        })()}
    </>
  );
}

export function AdminUsers({ loans, units, products, users, notify, refresh }) {
  const [search, setSearch] = useState(""),
    [program, setProgram] = useState("All"),
    [year, setYear] = useState("All"),
    [selected, setSelected] = useState(null),
    [statusPreview, setStatusPreview] = useState({}),
    [statusBusy, setStatusBusy] = useState(false);
  const students = users.filter((x) => x.role === "STUDENT");
  const shown = students.filter(
    (x) =>
      `${x.fullName} ${x.studentId} ${x.program} ${x.yearLevel}`
        .toLowerCase()
        .includes(search.toLowerCase()) &&
      (program === "All" || x.program === program) &&
      (year === "All" || x.yearLevel === year),
  );
  return (
    <>
      <PageHead
        eyebrow="ADMIN / USERS"
        title="Students"
        description="Review student profiles, account status, and borrowing activity."
      />
      <div className="panel">
        <div className="filter-grid users-filters">
          <SearchBox
            value={search}
            onChange={setSearch}
            placeholder="Search name, ID, program, or year"
          />
          <select
            value={program}
            onChange={(e) => setProgram(e.target.value)}
            aria-label="Program"
          >
            <option>All</option>
            {[...new Set(students.map((x) => x.program))].map((x) => (
              <option key={x}>{x}</option>
            ))}
          </select>
          <select
            value={year}
            onChange={(e) => setYear(e.target.value)}
            aria-label="Year level"
          >
            <option>All</option>
            {[...new Set(students.map((x) => x.yearLevel))].map((x) => (
              <option key={x}>{x}</option>
            ))}
          </select>
        </div>
        <div className="panel-title table-title">
          <div>
            <span className="eyebrow">STUDENT DIRECTORY</span>
            <h2>Student accounts</h2>
          </div>
          <span className="muted">{shown.length} students</span>
        </div>
        {shown.length ? (
          <div className="table-scroll">
            <table>
              <thead>
                <tr>
                  <th>Student</th>
                  <th>Student ID</th>
                  <th>Program</th>
                  <th>Year</th>
                  <th>Active loans</th>
                  <th>Account</th>
                </tr>
              </thead>
              <tbody>
                {shown.map((student) => (
                  <tr className="click-row" key={student.id}>
                    <td>
                      <button className="table-user table-row-link" onClick={() => setSelected(student)} aria-label={`View ${student.fullName}'s profile`}>
                        <span className="avatar small-avatar">
                          {student.fullName
                            .split(" ")
                            .map((x) => x[0])
                            .join("")}
                        </span>
                        <span>
                          <strong>{student.fullName}</strong>
                          <small>{student.schoolEmail}</small>
                        </span>
                      </button>
                    </td>
                    <td>{student.studentId}</td>
                    <td>{student.program}</td>
                    <td>{student.yearLevel}</td>
                    <td>
                      {
                        loans.filter(
                          (x) =>
                            x.studentId === student.id && x.status === "ACTIVE",
                        ).length
                      }
                    </td>
                    <td>
                      <Badge
                        tone={
                          (statusPreview[student.id] ||
                            student.accountStatus) === "Active"
                            ? "success"
                            : "danger"
                        }
                      >
                        {statusPreview[student.id] || student.accountStatus}
                      </Badge>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <Empty
            icon={Users}
            title="No matching students"
            text="Try another search or filter."
          />
        )}
      </div>
      {selected && (
        <Modal
          title="Student profile"
          onClose={() => setSelected(null)}
          size="wide"
        >
          <div className="student-detail-head">
            <span className="avatar detail-avatar">
              {selected.fullName
                .split(" ")
                .map((x) => x[0])
                .join("")}
            </span>
            <div>
              <h2>{selected.fullName}</h2>
              <p>
                {selected.program} · {selected.yearLevel}
              </p>
              <Badge
                tone={
                  (statusPreview[selected.id] || selected.accountStatus) ===
                  "Active"
                    ? "success"
                    : "danger"
                }
              >
                {statusPreview[selected.id] || selected.accountStatus}
              </Badge>
            </div>
          </div>
          <div className="details-list">
            <div>
              <span>Student ID</span>
              <strong>{selected.studentId}</strong>
            </div>
            <div>
              <span>School email</span>
              <strong>{selected.schoolEmail}</strong>
            </div>
            <div>
              <span>Address</span>
              <strong>{selected.address}</strong>
            </div>
          </div>
          <h3 className="subheading">Borrowing & return history</h3>
          {loans.filter((x) => x.studentId === selected.id).length ? (
            loans
              .filter((x) => x.studentId === selected.id)
              .map((loan) => {
                const unit = unitOf(loan, units),
                  product = productOf(unit, products);
                return (
                  <div className="unit-row" key={loan.id}>
                    <span>
                      <strong>{product?.name}</strong>
                      <small>
                        {loan.loanNumber} · {unit?.itemCode} · Due{" "}
                        {pretty(loan.expectedReturnAt)}
                      </small>
                    </span>
                    <Badge
                      tone={
                        isOverdue(loan)
                          ? "danger"
                          : loan.status === "RETURNED"
                            ? "success"
                            : "warning"
                      }
                    >
                      {isOverdue(loan) ? "Overdue" : loan.status}
                    </Badge>
                  </div>
                );
              })
          ) : (
            <Empty title="No loan records" />
          )}
          <div className="modal-actions">
            <button
              className="button secondary"
              onClick={() => setSelected(null)}
            >
              Close
            </button>
            <button
              className="button"
              disabled={statusBusy}
              onClick={async () => {
                if (statusBusy) return;
                const next =
                  (statusPreview[selected.id] || selected.accountStatus) ===
                  "Active"
                    ? "Suspended"
                    : "Active";
                setStatusBusy(true);
                try {
                  const response = await apiService.setStudentStatus(selected.id, next);
                  if (!response.ok) throw new Error(response.error?.message || "Could not validate account status.");
                  setStatusPreview((old) => ({ ...old, [selected.id]: next }));
                  await refresh();
                  notify(`Account ${next.toLowerCase()}.`);
                } catch (statusError) {
                  notify(statusError.message || "Could not validate account status. Try again.", "error");
                } finally {
                  setStatusBusy(false);
                }
              }}
            >
              {(statusPreview[selected.id] || selected.accountStatus) ===
              "Active"
                ? "suspend"
                : "activate"}
            </button>
          </div>
        </Modal>
      )}
    </>
  );
}
