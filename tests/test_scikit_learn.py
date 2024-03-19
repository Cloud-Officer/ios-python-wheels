#!/usr/bin/env python3

from sklearn.datasets import make_classification, load_digits
from sklearn.model_selection import train_test_split, cross_val_score
from sklearn.preprocessing import StandardScaler, PolynomialFeatures, MinMaxScaler
from sklearn.decomposition import PCA
from sklearn.manifold import TSNE, MDS, Isomap
from sklearn.cluster import KMeans, DBSCAN, AgglomerativeClustering
from sklearn.ensemble import GradientBoostingClassifier, HistGradientBoostingClassifier, RandomForestClassifier
from sklearn.linear_model import LogisticRegression, SGDClassifier, RidgeClassifier
from sklearn.metrics import silhouette_score, accuracy_score, roc_auc_score
from sklearn.neighbors import KNeighborsClassifier, BallTree, NearestNeighbors
from sklearn.svm import SVC
from sklearn.tree import DecisionTreeClassifier, ExtraTreeClassifier
from sklearn.utils import shuffle, resample

# Generate synthetic dataset
X, y = make_classification(n_samples=1000, n_features=20, n_informative=15, n_redundant=5, random_state=42)
X, y = shuffle(X, y, random_state=42)
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.25, random_state=42)

# Additional Datasets
digits = load_digits()
X_digits, y_digits = digits.data, digits.target
X_digits = MinMaxScaler().fit_transform(X_digits)

# Preprocessing
scaler = StandardScaler().fit(X_train)
X_train_scaled = scaler.transform(X_train)
X_test_scaled = scaler.transform(X_test)

# Feature extraction
poly_features = PolynomialFeatures(degree=3).fit_transform(X_train_scaled)

# Decomposition
# don't work for new wheels
# pca = PCA(n_components=5).fit_transform(X_train_scaled)

# Manifold Learning
# tsne = TSNE(n_components=3).fit_transform(X_train_scaled)
# mds = MDS(n_components=2).fit_transform(X_digits[:100])  # MDS is computationally expensive
# isomap = Isomap(n_components=2).fit_transform(X_digits[:100])

# Clustering
kmeans = KMeans(n_clusters=5).fit(X_train_scaled)
dbscan = DBSCAN(eps=0.5).fit(X_train_scaled)
agglo = AgglomerativeClustering(n_clusters=5).fit(X_train_scaled)

# Ensemble Methods
# gb = GradientBoostingClassifier().fit(X_train_scaled, y_train)
hgb = HistGradientBoostingClassifier().fit(X_train_scaled, y_train)
# rf = RandomForestClassifier().fit(X_train_scaled, y_train)

# Linear Models
log_reg = LogisticRegression().fit(X_train_scaled, y_train)
sgd_clf = SGDClassifier().fit(X_train_scaled, y_train)
ridge = RidgeClassifier().fit(X_train_scaled, y_train)

# Neighbors
knn = KNeighborsClassifier().fit(X_train_scaled, y_train)
nn = NearestNeighbors(n_neighbors=5).fit(X_train_scaled)
# ball_tree = BallTree(X_train_scaled, leaf_size=50)

# SVM
svc = SVC().fit(X_train_scaled, y_train)

# Decision Trees
# tree_clf = DecisionTreeClassifier().fit(X_train_scaled, y_train)
#extra_tree_clf = ExtraTreeClassifier().fit(X_train_scaled, y_train)

# Metrics
accuracy = accuracy_score(y_test, log_reg.predict(X_test_scaled))
roc_auc = roc_auc_score(y_test, log_reg.predict_proba(X_test_scaled)[:, 1])
silhouette_avg = silhouette_score(X_train_scaled, kmeans.labels_)

# Utils
X_resampled, y_resampled = resample(X_train_scaled, y_train, n_samples=200, random_state=42)

print("Completed an extensive demonstration of scikit-learn functionalities.")
