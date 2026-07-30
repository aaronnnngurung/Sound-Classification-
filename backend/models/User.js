module.exports = (sequelize, DataTypes) => {
  const User = sequelize.define('User', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true,
    },
    firebaseUid: {
      type: DataTypes.STRING,
      allowNull: false,
      unique: true,
    },
    email: {
      type: DataTypes.STRING,
      allowNull: false,
      unique: true,
    },
    displayName: {
      type: DataTypes.STRING,
      allowNull: true,
    },
    role: {
      type: DataTypes.ENUM('user', 'admin'),
      defaultValue: 'user',
      allowNull: false,
    },
  }, {
    timestamps: true,
    tableName: 'Users',
  });

  User.associate = (db) => {
    User.hasMany(db.FalseNegativeReport, { foreignKey: 'userId', as: 'reports' });
    User.hasMany(db.FalseNegativeReport, { foreignKey: 'reviewedBy', as: 'reviews' });
  };

  return User;
};
