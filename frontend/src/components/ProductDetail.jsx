import { ArrowRight, QrCode, Info } from "lucide-react";
import { Badge, Empty, Modal, ProductArt } from "../components/ui";

export function ProductDetail({
  product,
  units,
  onClose,
  navigate,
  admin = false,
}) {
  const matching = units.filter((unit) => unit.productId === product.id);
  return (
    <Modal title="Equipment details" onClose={onClose} size="wide">
      <div className="detail-hero">
        <ProductArt product={product} size="large" />
        <div>
          <span className="eyebrow">
            {product.equipmentId} · {product.category}
          </span>
          <h2>{product.name}</h2>
          <p>{product.description}</p>
          <Badge tone={product.availableUnits ? "success" : "danger"}>
            {product.availableUnits
              ? `${product.availableUnits} available units`
              : "No units available"}
          </Badge>
        </div>
      </div>
      <div className="detail-note">
        <Info size={17} /> Availability counts individually coded physical
        units. Scan the exact item you intend to borrow.
      </div>
      <h3 className="subheading">Physical units</h3>
      <div className="unit-list">
        {matching.length ? (
          matching.map((unit) => (
            <div className="unit-row" key={unit.id}>
              <span className="unit-code">
                <QrCode size={17} /> {unit.itemCode}
              </span>
              <span className="muted">Serial {unit.serialNumber}</span>
              <Badge
                tone={
                  unit.status === "AVAILABLE"
                    ? "success"
                    : unit.status === "BORROWED"
                      ? "warning"
                      : "danger"
                }
              >
                {unit.status === "MAINTENANCE"
                  ? "Maintenance"
                  : unit.status === "BORROWED"
                    ? "Borrowed"
                    : "Available"}
              </Badge>
            </div>
          ))
        ) : (
          <Empty
            title="No fixture units"
            text="Receiving new units requires a backend to confirm stock."
          />
        )}
      </div>
      <div className="modal-actions">
        <button className="button secondary" onClick={onClose}>
          Close
        </button>
        <button
          className="button"
          onClick={() => {
            onClose();
            navigate(admin ? "/admin/scan" : "/student/scan");
          }}
        >
          {admin ? "Open scan desk" : "Scan a unit"} <ArrowRight size={17} />
        </button>
      </div>
    </Modal>
  );
}
