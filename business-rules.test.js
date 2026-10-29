const test=require("node:test");const assert=require("node:assert/strict");
function month(d){if(!/^\d{4}-\d{2}-\d{2}$/.test(d))throw Error("tanggal tidak valid");return d.slice(0,7)}
function chargeable(r,p){if(!/^\d{4}-(0[1-9]|1[0-2])$/.test(p))throw Error("periode tidak valid");if(p<month(r.mulai_wajib))return false;if(r.status==="aktif")return true;if(!r.tanggal_efektif_status)return false;return p<month(r.tanggal_efektif_status)}
test("warga mulai Maret tidak ditagih Januari-Februari",()=>{const r={mulai_wajib:"2026-03-01",status:"aktif"};assert.equal(chargeable(r,"2026-01"),false);assert.equal(chargeable(r,"2026-02"),false);assert.equal(chargeable(r,"2026-03"),true)});
test("warga keluar tidak ditagih setelah bulan efektif",()=>{const r={mulai_wajib:"2025-01-01",status:"keluar",tanggal_efektif_status:"2026-06-15"};assert.equal(chargeable(r,"2026-05"),true);assert.equal(chargeable(r,"2026-06"),false);assert.equal(chargeable(r,"2026-07"),false)});
test("tanggal/periode invalid ditolak",()=>{assert.throws(()=>month("2026/01/01"));assert.throws(()=>chargeable({mulai_wajib:"2026-01-01",status:"aktif"},"2026-13"))});
