const loadImage = (source) => new Promise((resolve, reject) => {
  const image = new Image();
  image.onload = () => resolve(image);
  image.onerror = reject;
  image.src = source;
});

export async function downloadReceipt({ loan, receipt, unit, product, user, format }) {
  const QRCode = (await import("qrcode")).default;
  const canvas = document.createElement("canvas");
  canvas.width = 700;
  canvas.height = 980;
  const ctx = canvas.getContext("2d");
  ctx.fillStyle = "#fff";
  ctx.fillRect(0, 0, 700, 980);
  ctx.fillStyle = "#0b3d2e";
  ctx.fillRect(0, 0, 700, 118);
  ctx.fillStyle = "#fff";
  ctx.font = "bold 38px Arial";
  ctx.fillText("ENcoRE", 54, 72);
  ctx.font = "15px Arial";
  ctx.fillText("EQUIPMENT LOAN RECEIPT", 54, 98);
  ctx.fillStyle = "#183c32";
  ctx.font = "bold 20px Arial";
  ctx.fillText(receipt?.receiptNumber || loan.loanNumber || "Loan receipt", 54, 165);

  const rows = [
    ["Borrower", user.fullName],
    ["Student ID", user.studentId],
    ["Email", user.schoolEmail],
    ["Equipment", product?.name || "Equipment"],
    ["Item code", unit?.itemCode || ""],
    ["Serial", unit?.serialNumber || ""],
    ["Borrowed", new Date(loan.borrowedAt).toLocaleString("en-PH")],
    ["Return by", new Date(loan.expectedReturnAt).toLocaleString("en-PH")],
    ["Status", loan.status === "RETURNED" ? "Returned" : "Active"],
  ];
  rows.forEach(([label, value], index) => {
    const y = 215 + index * 55;
    ctx.fillStyle = "#617168";
    ctx.font = "14px Arial";
    ctx.fillText(label.toUpperCase(), 54, y);
    ctx.fillStyle = "#172c26";
    ctx.font = "bold 17px Arial";
    ctx.fillText(String(value || "—").slice(0, 54), 230, y);
    ctx.strokeStyle = "#e5ebe7";
    ctx.beginPath();
    ctx.moveTo(54, y + 16);
    ctx.lineTo(646, y + 16);
    ctx.stroke();
  });
  const qrPayload = JSON.stringify({
    receipt: receipt?.receiptNumber || loan.loanNumber,
    studentId: user.studentId,
    name: user.fullName,
    email: user.schoolEmail,
    itemCode: unit?.itemCode,
    dueAt: loan.expectedReturnAt,
  });
  const qrImage = await loadImage(await QRCode.toDataURL(qrPayload, { width: 165, margin: 1 }));
  ctx.drawImage(qrImage, 267, 740, 165, 165);
  ctx.fillStyle = "#617168";
  ctx.font = "13px Arial";
  ctx.textAlign = "center";
  ctx.fillText("Scan to read receipt and borrower details", 350, 930);
  ctx.textAlign = "left";

  const name = `ENcoRE-${receipt?.receiptNumber || loan.id}`;
  if (format === "pdf") {
    const { jsPDF } = await import("jspdf");
    const pdf = new jsPDF({ orientation: "portrait", unit: "px", format: [700, 980] });
    pdf.addImage(canvas.toDataURL("image/png"), "PNG", 0, 0, 700, 980);
    pdf.save(`${name}.pdf`);
    return;
  }
  const blob = await new Promise((resolve) => canvas.toBlob(resolve, "image/png"));
  if (!blob) throw new Error("Could not create PNG receipt.");
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = `${name}.png`;
  link.click();
  setTimeout(() => URL.revokeObjectURL(url), 30000);
}
