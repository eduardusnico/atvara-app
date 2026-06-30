import 'package:supabase_flutter/supabase_flutter.dart';

/// Default company list — used if the Supabase table is empty or unavailable.
const List<String> kDefaultCompanies = [
  'PT Indivara Sejahtera Sukses Makmur',
  'PT Indivara Sejahtera Mandiri',
  'PT Jati Piranti Solusindo',
  'PT Indivara Teknologi Quantum',
  'PT Danendra Mentari Sejahtera atau PT Dinamika Mitra Sukses Makmur',
  'PT Teknologi Optimal Perkasa',
  'PT Corbit Teknologi Mandiri',
  'PT Warung Sejahtera Maju Makmur',
  'PT Jasa Kelola Asia',
  'PT Informasi Teknologi Indonesia',
  'PT Loket Pintar Indonesia',
  'PT Bersama Merah Putih Sejahtera',
  'Solution Exchange, Inc.',
  'PT Informasi Teknologi Indonesia, Tbk',
  'Other',
];

class CompanyService {
  static SupabaseClient get _db => Supabase.instance.client;

  /// Returns companies from Supabase. Falls back to [kDefaultCompanies] on
  /// any error or if the table is empty.
  static Future<List<String>> getCompanies() async {
    try {
      final data = await _db
          .from('companies')
          .select('name')
          .order('name', ascending: true);
      final names = (data as List<dynamic>)
          .map((row) => row['name'] as String)
          .toList();
      return names.isEmpty ? kDefaultCompanies : names;
    } catch (_) {
      return kDefaultCompanies;
    }
  }

  /// Adds a new company. Throws on duplicate or DB error.
  static Future<void> addCompany(String name) async {
    await _db.from('companies').insert({'name': name.trim()});
  }

  /// Deletes a company by name.
  static Future<void> deleteCompany(String name) async {
    await _db.from('companies').delete().eq('name', name);
  }
}
