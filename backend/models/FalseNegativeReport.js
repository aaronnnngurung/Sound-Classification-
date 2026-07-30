module.exports = (sequelize, DataTypes) => {
  const FalseNegativeReport = sequelize.define('FalseNegativeReport', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true,
    },
    userId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: { model: 'Users', key: 'id' },
    },
    soundType: {
      type: DataTypes.STRING,
      allowNull: true,
    },
    description: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
    occurredAt: {
      type: DataTypes.DATE,
      allowNull: false,
    },
    deviceInfo: {
      type: DataTypes.STRING,
      allowNull: true,
    },
    status: {
      type: DataTypes.ENUM('open', 'reviewed', 'resolved'),
      defaultValue: 'open',
      allowNull: false,
    },
    reviewedBy: {
      type: DataTypes.INTEGER,
      allowNull: true,
      references: { model: 'Users', key: 'id' },
    },
    adminNotes: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
  }, {
    timestamps: true,
    tableName: 'FalseNegativeReports',
  });

  FalseNegativeReport.associate = (db) => {
    FalseNegativeReport.belongsTo(db.User, { foreignKey: 'userId', as: 'user' });
    FalseNegativeReport.belongsTo(db.User, { foreignKey: 'reviewedBy', as: 'reviewer' });
  };

  return FalseNegativeReport;
};
