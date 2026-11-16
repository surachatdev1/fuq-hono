# PSD employee payslips

This web feature reads the authenticated employee's issued payroll periods,
their source totals and line items, and the PDF supplied by HONO. Amounts are
copied as strings without recalculation, rounding or default zero values.

The legacy Android implementation was inspected in HONO HR 22.9 (323), APK
SHA-256 `99440c33ecda95a3ac9eac329d7874fef80c804ccc55ed977e6756ada71ef9dc`.
The request sequence follows the APK's payroll constants and URL builder,
the salary response models, and the PDF callback. Android 23.1 (324), base APK
SHA-256 `e44696fddf25537e878e57ab5c7da04d517736f8a5ba1735e3af2c26af75df42`,
retains the same legacy endpoint constants, response fields and employee
payroll request sequence.

| HONO operation | Source data |
| --- | --- |
| `getEmpPayrollYear` | `finYear[].FY`, `Selected`, pay group and site flags |
| `getEmpPayrollMonth` | `MONTH[].MONTHCODE`, `MONTH[].PAYDATE`, `CURRENT_CODE` |
| `payrollEncryption` | The provider's payroll reference for the current employee |
| `getEmpSalary` | `GROSSPAY`, `GROSSDED`, `NETPAY`, and the four source line item categories |
| `getEmpPaySlip` | HONO's original document |

The server checks the upstream session and the selected year and period before
reading a slip. The browser account must match the session cookie. Results carry
`Cache-Control: no-store`, and file downloads are restricted to the tenant's
trusted HONO hosts. Pay group and site-specific configurations require the
official app until their separate workflow is verified.

Static APK evidence and test fixtures cover the legacy contract. Confirm one PSD
employee's issued period against the same source PDF before production rollout.
