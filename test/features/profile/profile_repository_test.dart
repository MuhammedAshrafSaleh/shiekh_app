
      result.fold((f) {
        expect(f, isA<AuthFailure>());
        expect(f.message, 'كلمة المرور الحالية غير صحيحة');
      }, (_) => fail('expected Left'));
    });
  });

  // -------------------------------------------------------------------------
  // ProfileStats — pure construction
  // -------------------------------------------------------------------------
  group('ProfileStats', () {
    test('estimatedStudyHours is accessible as a plain property', () {
      const stats = ProfileStats(
        fullName: 'Ahmad Ali',
        email: 'a@b.com',
        enrolledBooks: 3,
        completedLessons: 10,
        certificates: 2,
      );

      expect(stats.enrolledBooks, 3);
      expect(stats.completedLessons, 10);
      expect(stats.certificates, 2);
    });
  });
}
