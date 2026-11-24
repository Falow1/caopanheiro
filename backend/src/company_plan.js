import { onCall } from './callable.js';
import { actor, identifier, localBackend, object, options, teamAccess } from './runtime.js';
import { staffSeatOccupied } from './manager_activation.js';
import { staffMembers, STAFF_QUERY_LIMIT } from './staff_members.js';

// Read-only view of the contracted plan for the managers of a petshop.
// Changing plan or subscription remains an administrative action of the SaaS.
export const getCompanyPlan = onCall(options, async (request) => {
  const db = localBackend(); const uid = await actor(request);
  object(request.data, ['tenantId'], 'Consulta');
  const tenantId = identifier(request.data.tenantId, 'Empresa');
  return db.runTransaction(async (tx) => {
    // While the access is paused (E2), the principal manager still reads the plan.
    const access = await teamAccess(tx, db, tenantId, uid, ['MANAGER'], { pausedPrincipal: true });
    const subscription = await tx.get(db.doc(`subscriptions/${tenantId}`));
    const planId = subscription.get('planId') ?? access.tenant.get('planId');
    const plan = typeof planId === 'string' && planId ? await tx.get(db.doc(`plans/${planId}`)) : null;
    const members = await staffMembers(tx, db, tenantId, { allowCapped: true });
    const professionals = await tx.get(db.collection(`tenants/${tenantId}/professionals`).where('active', '==', true).limit(101));
    return {
      plan: plan?.exists ? { name: plan.get('name') ?? '', description: plan.get('description') ?? '',
        maxUsers: plan.get('maxUsers') ?? null, maxProfessionals: plan.get('maxProfessionals') ?? null,
        monthlyPriceCents: plan.get('monthlyPriceCents') ?? null, features: plan.get('features') ?? [] } : null,
      subscription: { status: subscription.get('status') ?? null, renewsAt: subscription.get('renewsAt')?.toDate?.().toISOString() ?? null },
      usage: { users: members.docs.filter((doc) => staffSeatOccupied(doc.data())).length, usersCapped: members.size > STAFF_QUERY_LIMIT,
        professionals: Math.min(professionals.size, 100), professionalsCapped: professionals.size > 100 },
    };
  });
});
